import Foundation
import CoreML
import AVFoundation
import Accelerate

/// Production on-device 6-stem source separation using CoreML Dense U-Net.
///
/// Model: dun_tfc_tdf_b9_l3_w_6stems_32_fp32_v2.0.1
///   Input:  "mixture"  [1, 4, 32, 2048]  — stereo STFT (Re_L, Im_L, Re_R, Im_R) × 32 time-frames × 2048 freq-bins
///   Output: 6 stems, each [1, 4, 32, 2048] — raw STFT per stem
///
/// Pipeline: Load audio → stereo resample 44100 → STFT → chunk → CoreML → iSTFT → write M4A
public class CoreMLStemSeparator {

    private var nFFT = 4096
    private var hopSize = 1024
    private var nBins = 2048           // nFFT / 2
    private var chunkFrames = 32       // model time-axis size
    private let targetSampleRate: Double = 44100.0
    private let stemNames = ["vocals", "drums", "bass", "guitar", "piano", "other"]

    private let featureExtractor = AudioFeatureExtractor()

    public init() {}

    // MARK: - Public API

    /// Separates a local mixture audio file into six separate stem tracks using CoreML inference.
    /// Falls back to bundle demo assets if the model is not available or inference fails.
    private func transcodeToWavIfNeeded(url: URL) async throws -> URL {
        do {
            let _ = try AVAudioFile(forReading: url)
            print("[StemSeparator] Input file is readable natively.")
            return url
        } catch {
            print("[StemSeparator] Native read failed: \(error.localizedDescription). Attempting transcoding...")
        }

        let asset = AVAsset(url: url)
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempM4aURL = tempDir.appendingPathComponent("transcoded_\(UUID().uuidString).m4a")
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "CoreMLStemSeparator", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "Gagal membuat sesi transcode audio."])
        }
        
        exportSession.outputURL = tempM4aURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            print("[StemSeparator] Transcoded successfully to: \(tempM4aURL.lastPathComponent)")
            return tempM4aURL
        } else {
            let exportError = exportSession.error ?? NSError(domain: "CoreMLStemSeparator", code: 500,
                                                            userInfo: [NSLocalizedDescriptionKey: "Gagal melakukan transcoding audio."])
            throw exportError
        }
    }

    public func separate(
        audioURL: URL,
        processingMode: String?,
        modelQuality: String?,
        onProgress: @escaping (String, Double) -> Void
    ) async throws -> [String: URL] {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw NSError(domain: "CoreMLStemSeparator", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Input mixture file not found at \(audioURL.path)"])
        }

        onProgress("Memulai pemisahan stem...", 0.02)
        print("[StemSeparator] Starting separation on: \(audioURL.lastPathComponent)")

        // 1. Transcode if needed
        onProgress("Memeriksa format file audio...", 0.04)
        let readableURL = try await transcodeToWavIfNeeded(url: audioURL)

        do {
            let result = try await runRealInference(audioURL: readableURL, processingMode: processingMode, modelQuality: modelQuality, onProgress: onProgress)
            onProgress("Proses pemisahan stem berhasil diselesaikan!", 1.0)
            print("[StemSeparator] ✅ Real CoreML separation succeeded.")
            
            // Clean up temporary transcoded file if created
            if readableURL != audioURL {
                try? FileManager.default.removeItem(at: readableURL)
            }
            return result
        } catch {
            print("[StemSeparator] ⚠️ CoreML separation failed: \(error.localizedDescription)")
            
            // Clean up temporary transcoded file if created
            if readableURL != audioURL {
                try? FileManager.default.removeItem(at: readableURL)
            }
            
            throw error
        }
    }

    // MARK: - Real CoreML Inference Pipeline

    private func runRealInference(
        audioURL: URL,
        processingMode: String?,
        modelQuality: String?,
        onProgress: @escaping (String, Double) -> Void
    ) async throws -> [String: URL] {
        // 1. Load CoreML model
        onProgress("Memuat model CoreML...", 0.05)
        let model = try loadModel(processingMode: processingMode, modelQuality: modelQuality)

        // 2. Decode audio to stereo PCM @ 44100 Hz
        onProgress("Melakukan decoding format audio campuran...", 0.1)
        let (leftChannel, rightChannel) = try loadStereoAudio(url: audioURL)
        print("[StemSeparator] Audio loaded: \(leftChannel.count) samples per channel")

        // Normalize volume of left/right channels
        var maxVal: Float = 0.0
        for i in 0..<leftChannel.count {
            let absL = abs(leftChannel[i])
            if absL > maxVal { maxVal = absL }
        }
        for i in 0..<rightChannel.count {
            let absR = abs(rightChannel[i])
            if absR > maxVal { maxVal = absR }
        }
        
        var normalizedLeft = leftChannel
        var normalizedRight = rightChannel
        if maxVal > 0.0 && maxVal < 0.95 {
            let scale = 0.95 / maxVal
            for i in 0..<leftChannel.count {
                normalizedLeft[i] *= scale
            }
            for i in 0..<rightChannel.count {
                normalizedRight[i] *= scale
            }
            print("[StemSeparator] Normalized audio volume by scale: \(scale)")
        }

        // 3. Compute STFT for both channels
        onProgress("Menghitung analisis frekuensi (STFT)...", 0.2)
        let leftSTFT = computeChannelSTFT(samples: normalizedLeft)
        let rightSTFT = computeChannelSTFT(samples: normalizedRight)
        let totalFrames = leftSTFT.real.count
        print("[StemSeparator] STFT computed: \(totalFrames) frames × \(nBins) bins")

        guard totalFrames > 0 else {
            throw NSError(domain: "CoreMLStemSeparator", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "STFT produced zero frames"])
        }

        // 4. Chunk, run inference, collect output STFT per stem
        var stemSTFTs: [String: (realL: [[Float]], imagL: [[Float]], realR: [[Float]], imagR: [[Float]])] = [:]
        for name in stemNames {
            stemSTFTs[name] = (
                realL: [[Float]](repeating: [Float](repeating: 0, count: nBins), count: totalFrames),
                imagL: [[Float]](repeating: [Float](repeating: 0, count: nBins), count: totalFrames),
                realR: [[Float]](repeating: [Float](repeating: 0, count: nBins), count: totalFrames),
                imagR: [[Float]](repeating: [Float](repeating: 0, count: nBins), count: totalFrames)
            )
        }

        // Process in chunks of chunkFrames with 50% overlap for smooth transitions
        let overlap = chunkFrames / 2
        let step = chunkFrames - overlap
        var chunkStart = 0
        var chunkCount = 0

        let totalChunks = Int(ceil(Double(totalFrames) / Double(step)))
        onProgress("Menjalankan inferensi neural network (\(totalChunks) chunks)...", 0.3)

        while chunkStart < totalFrames {
            let chunkEnd = min(chunkStart + chunkFrames, totalFrames)
            let actualFrames = chunkEnd - chunkStart

            // Build input tensor [1, 4, chunkFrames, nBins]
            let inputArray = try buildInputTensor(
                leftReal: leftSTFT.real, leftImag: leftSTFT.imag,
                rightReal: rightSTFT.real, rightImag: rightSTFT.imag,
                startFrame: chunkStart, frameCount: actualFrames
            )

            // Run CoreML inference
            let prediction = try model.prediction(from: inputArray)

            // Extract each stem's output and overlap-add into the full-length arrays
            for name in stemNames {
                guard let outputFeature = prediction.featureValue(for: name),
                      let multiArray = outputFeature.multiArrayValue else { continue }

                let (stemRealL, stemImagL, stemRealR, stemImagR) = extractStemSTFTStereo(from: multiArray, frameCount: actualFrames)

                // Overlap-add: use triangular (linear crossfade) window for overlapping region
                for f in 0..<actualFrames {
                    let globalFrame = chunkStart + f
                    guard globalFrame < totalFrames else { break }

                    // Crossfade weight for overlap region
                    var weight: Float = 1.0
                    if chunkStart > 0 && f < overlap {
                        weight = Float(f) / Float(overlap)
                    }

                    for b in 0..<nBins {
                        if chunkStart > 0 && f < overlap {
                            // Blend L
                            stemSTFTs[name]!.realL[globalFrame][b] =
                                stemSTFTs[name]!.realL[globalFrame][b] * (1.0 - weight) + stemRealL[f][b] * weight
                            stemSTFTs[name]!.imagL[globalFrame][b] =
                                stemSTFTs[name]!.imagL[globalFrame][b] * (1.0 - weight) + stemImagL[f][b] * weight
                            // Blend R
                            stemSTFTs[name]!.realR[globalFrame][b] =
                                stemSTFTs[name]!.realR[globalFrame][b] * (1.0 - weight) + stemRealR[f][b] * weight
                            stemSTFTs[name]!.imagR[globalFrame][b] =
                                stemSTFTs[name]!.imagR[globalFrame][b] * (1.0 - weight) + stemImagR[f][b] * weight
                        } else {
                            stemSTFTs[name]!.realL[globalFrame][b] = stemRealL[f][b]
                            stemSTFTs[name]!.imagL[globalFrame][b] = stemImagL[f][b]
                            stemSTFTs[name]!.realR[globalFrame][b] = stemRealR[f][b]
                            stemSTFTs[name]!.imagR[globalFrame][b] = stemImagR[f][b]
                        }
                    }
                }
            }

            chunkStart += step
            chunkCount += 1
            
            let currentProgress = 0.3 + (Double(chunkCount) / Double(totalChunks)) * 0.5
            if chunkCount % 5 == 0 || chunkStart >= totalFrames {
                onProgress("Memproses chunk \(chunkCount)/\(totalChunks) (\(min(chunkStart, totalFrames))/\(totalFrames) frame)", currentProgress)
                print("[StemSeparator] Processed \(chunkCount) chunks (\(min(chunkStart, totalFrames))/\(totalFrames) frames)")
            }
        }

        print("[StemSeparator] Inference complete: \(chunkCount) chunks processed")
        onProgress("Inference selesai. Rekonstruksi gelombang audio stereo (iSTFT)...", 0.8)

        // 5. iSTFT each stem → write M4A
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("stem_output_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var outputPaths: [String: URL] = [:]
        for (idx, name) in stemNames.enumerated() {
            let writeProgress = 0.8 + (Double(idx) / Double(stemNames.count)) * 0.18
            onProgress("Menulis file audio untuk stem: \(name.uppercased())", writeProgress)
            
            let stemData = stemSTFTs[name]!
            // Reconstruct stereo PCM
            guard let pcmBuffer = featureExtractor.computeISTFTStereo(
                realL: stemData.realL, imagL: stemData.imagL,
                realR: stemData.realR, imagR: stemData.imagR,
                nFFT: nFFT, hopSize: hopSize, sampleRate: targetSampleRate
            ) else {
                print("[StemSeparator] ⚠️ iSTFT failed for \(name), skipping")
                continue
            }

            let outputURL = outputDir.appendingPathComponent("\(name).m4a")
            try writeAudioBuffer(pcmBuffer, to: outputURL)
            
            // Validate output stem files
            let attr = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let fileSize = attr[.size] as? UInt64 ?? 0
            
            let valFile = try AVAudioFile(forReading: outputURL)
            let valFormat = valFile.processingFormat
            let valFrameLength = valFile.length
            let valDuration = Double(valFrameLength) / valFormat.sampleRate
            
            guard fileSize > 1024 else {
                throw NSError(domain: "CoreMLStemSeparator", code: 500,
                              userInfo: [NSLocalizedDescriptionKey: "File stem \(name) terlalu kecil (\(fileSize) bytes)"])
            }
            
            guard valDuration > 0.0 else {
                throw NSError(domain: "CoreMLStemSeparator", code: 500,
                              userInfo: [NSLocalizedDescriptionKey: "File stem \(name) memiliki durasi kosong"])
            }
            
            var peak: Float = 0.0
            var sumSquare: Float = 0.0
            let totalValSamples = Int(pcmBuffer.frameLength)
            
            if totalValSamples > 0, let valChannels = pcmBuffer.floatChannelData {
                let channelL = valChannels[0]
                for s in 0..<totalValSamples {
                    let val = abs(channelL[s])
                    if val > peak { peak = val }
                    sumSquare += val * val
                }
            }
            
            let rms = totalValSamples > 0 ? sqrt(sumSquare / Float(totalValSamples)) : 0.0
            
            print("[StemSeparator] --- Stem Validation: \(name) ---")
            print("  Path: \(outputURL.path)")
            print("  File Size: \(fileSize) bytes")
            print("  Duration: \(valDuration) s")
            print("  Sample Rate: \(valFormat.sampleRate) Hz")
            print("  Channels: \(valFormat.channelCount)")
            print("  Peak Value: \(peak)")
            print("  RMS Value: \(rms)")
            
            guard peak > 1e-5 else {
                throw NSError(domain: "CoreMLStemSeparator", code: 500,
                              userInfo: [NSLocalizedDescriptionKey: "File stem \(name) tidak menghasilkan suara (peak: \(peak))"])
            }
            
            outputPaths[name] = outputURL
            print("[StemSeparator] Wrote stereo \(name).m4a (\(pcmBuffer.frameLength) samples)")
        }

        return outputPaths
    }

    // MARK: - Model Loading

    private func loadModel(processingMode: String?, modelQuality: String?) throws -> MLModel {
        let preferredNames: [String]
        if let quality = modelQuality {
            if quality == "Model Ringan" {
                preferredNames = [
                    "dunlight_tfc_tdf_b9_l3_w_subv1_cirm_6stems_64_fp16_v2.0.0",
                    "dun_tfc_tdf_b9_l3_w_6stems_32_fp32_v2.0.1"
                ]
            } else {
                preferredNames = [
                    "dun_tfc_tdf_b9_l3_w_6stems_32_fp32_v2.0.1",
                    "dunlight_tfc_tdf_b9_l3_w_subv1_cirm_6stems_64_fp16_v2.0.0"
                ]
            }
        } else {
            // Default to Light version first because FP32 is too heavy/slow
            preferredNames = [
                "dunlight_tfc_tdf_b9_l3_w_subv1_cirm_6stems_64_fp16_v2.0.0",
                "dun_tfc_tdf_b9_l3_w_6stems_32_fp32_v2.0.1"
            ]
        }

        for modelName in preferredNames {
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                let config = MLModelConfiguration()
                if let mode = processingMode {
                    if mode == "CPU Only" {
                        config.computeUnits = .cpuOnly
                    } else if mode == "GPU Accel" {
                        config.computeUnits = .cpuAndGPU
                    } else {
                        config.computeUnits = .all
                    }
                } else {
                    config.computeUnits = .all
                }
                let model = try MLModel(contentsOf: modelURL, configuration: config)
                
                // Dynamically inspect model shapes
                if let inputDesc = model.modelDescription.inputDescriptionsByName["mixture"],
                   let constraint = inputDesc.multiArrayConstraint {
                    let shape = constraint.shape
                    if shape.count >= 4 {
                        self.chunkFrames = shape[2].intValue
                        self.nBins = shape[3].intValue
                        self.nFFT = self.nBins * 2
                        self.hopSize = self.nFFT / 4
                        print("[StemSeparator] Configured dynamic DSP parameters: nBins=\(self.nBins), chunkFrames=\(self.chunkFrames), nFFT=\(self.nFFT), hopSize=\(self.hopSize)")
                    }
                }
                
                print("[StemSeparator] Loaded CoreML model: \(modelName) with units: \(config.computeUnits)")
                return model
            }
        }

        throw NSError(domain: "CoreMLStemSeparator", code: 404,
                      userInfo: [NSLocalizedDescriptionKey: "No stem separation CoreML model found in bundle"])
    }

    // MARK: - Audio Loading (Stereo)

    private func loadStereoAudio(url: URL) throws -> (left: [Float], right: [Float]) {
        let audioFile = try AVAudioFile(forReading: url)
        let originalFormat = audioFile.processingFormat

        // Target format: stereo float32 @ 44100 Hz
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 2,
            interleaved: false
        ) else {
            throw NSError(domain: "CoreMLStemSeparator", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }

        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let readBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            throw NSError(domain: "CoreMLStemSeparator", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create read buffer"])
        }

        try audioFile.read(into: readBuffer)

        // Resample if needed
        let outputBuffer: AVAudioPCMBuffer
        if originalFormat.sampleRate != targetSampleRate || originalFormat.channelCount != 2 {
            let ratio = targetSampleRate / originalFormat.sampleRate
            let estimatedFrames = AVAudioFrameCount(Double(readBuffer.frameLength) * ratio) + 1024

            guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames),
                  let converter = AVAudioConverter(from: originalFormat, to: targetFormat) else {
                throw NSError(domain: "CoreMLStemSeparator", code: 500,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
            }

            var error: NSError?
            var consumed = false
            converter.convert(to: outBuf, error: &error) { _, outStatus in
                if consumed {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return readBuffer
            }
            if let err = error { throw err }
            outputBuffer = outBuf
        } else {
            outputBuffer = readBuffer
        }

        guard let channelData = outputBuffer.floatChannelData else {
            throw NSError(domain: "CoreMLStemSeparator", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "No float channel data in buffer"])
        }

        let length = Int(outputBuffer.frameLength)
        let leftChannel = Array(UnsafeBufferPointer(start: channelData[0], count: length))

        // If stereo, use channel 1; if mono after conversion, duplicate
        let rightChannel: [Float]
        if outputBuffer.format.channelCount >= 2 {
            rightChannel = Array(UnsafeBufferPointer(start: channelData[1], count: length))
        } else {
            rightChannel = leftChannel
        }

        return (leftChannel, rightChannel)
    }

    // MARK: - STFT (per channel)

    private func computeChannelSTFT(samples: [Float]) -> (real: [[Float]], imag: [[Float]]) {
        let log2n = vDSP_Length(log2(Double(nFFT)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return ([], []) }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfN = nFFT / 2
        var hanningWindow = [Float](repeating: 0, count: nFFT)
        vDSP_hann_window(&hanningWindow, vDSP_Length(nFFT), Int32(vDSP_HANN_NORM))

        var realFrames: [[Float]] = []
        var imagFrames: [[Float]] = []

        var frameStart = 0
        while frameStart + nFFT <= samples.count {
            var windowed = [Float](repeating: 0, count: nFFT)
            let frameSlice = Array(samples[frameStart..<(frameStart + nFFT)])
            vDSP_vmul(frameSlice, 1, hanningWindow, 1, &windowed, 1, vDSP_Length(nFFT))

            var realPart = [Float](repeating: 0, count: halfN)
            var imagPart = [Float](repeating: 0, count: halfN)

            windowed.withUnsafeMutableBufferPointer { ptr in
                realPart.withUnsafeMutableBufferPointer { rBuf in
                    imagPart.withUnsafeMutableBufferPointer { iBuf in
                        var splitComplex = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                        ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                        }
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    }
                }
            }

            realFrames.append(realPart)
            imagFrames.append(imagPart)
            frameStart += hopSize
        }

        return (realFrames, imagFrames)
    }

    // MARK: - Tensor Construction

    /// Builds CoreML input tensor [1, 4, 32, 2048] from stereo STFT frames.
    /// Channel order: [Re_L, Im_L, Re_R, Im_R]
    private func buildInputTensor(
        leftReal: [[Float]], leftImag: [[Float]],
        rightReal: [[Float]], rightImag: [[Float]],
        startFrame: Int, frameCount: Int
    ) throws -> MLFeatureProvider {
        let shape: [NSNumber] = [1, 4, NSNumber(value: chunkFrames), NSNumber(value: nBins)]
        let multiArray = try MLMultiArray(shape: shape, dataType: .float32)

        // Zero-fill the entire array (handles padding if frameCount < chunkFrames)
        let totalElements = 1 * 4 * chunkFrames * nBins
        for i in 0..<totalElements {
            multiArray[i] = NSNumber(value: Float(0))
        }

        // Fill with actual data
        for f in 0..<frameCount {
            let srcFrame = startFrame + f
            guard srcFrame < leftReal.count else { break }

            for b in 0..<min(nBins, leftReal[srcFrame].count) {
                // Index: [0, channel, frame, bin]
                let baseIdx = f * nBins + b

                multiArray[0 * chunkFrames * nBins + baseIdx] = NSNumber(value: leftReal[srcFrame][b])   // Re_L
                multiArray[1 * chunkFrames * nBins + baseIdx] = NSNumber(value: leftImag[srcFrame][b])   // Im_L
                multiArray[2 * chunkFrames * nBins + baseIdx] = NSNumber(value: rightReal[srcFrame][b])  // Re_R
                multiArray[3 * chunkFrames * nBins + baseIdx] = NSNumber(value: rightImag[srcFrame][b])  // Im_R
            }
        }

        let featureValue = MLFeatureValue(multiArray: multiArray)
        let provider = try MLDictionaryFeatureProvider(dictionary: ["mixture": featureValue])
        return provider
    }

    // MARK: - Output Extraction

    /// Extracts real and imaginary STFT frames from a model output MultiArray [1, 4, chunkFrames, nBins].
    /// Returns stereo real/imag arrays for Left and Right channels.
    private func extractStemSTFTStereo(
        from multiArray: MLMultiArray,
        frameCount: Int
    ) -> (realL: [[Float]], imagL: [[Float]], realR: [[Float]], imagR: [[Float]]) {
        var realLFrames: [[Float]] = []
        var imagLFrames: [[Float]] = []
        var realRFrames: [[Float]] = []
        var imagRFrames: [[Float]] = []

        for f in 0..<frameCount {
            var realLBins = [Float](repeating: 0, count: nBins)
            var imagLBins = [Float](repeating: 0, count: nBins)
            var realRBins = [Float](repeating: 0, count: nBins)
            var imagRBins = [Float](repeating: 0, count: nBins)

            for b in 0..<nBins {
                let idxReL = 0 * chunkFrames * nBins + f * nBins + b
                let idxImL = 1 * chunkFrames * nBins + f * nBins + b
                let idxReR = 2 * chunkFrames * nBins + f * nBins + b
                let idxImR = 3 * chunkFrames * nBins + f * nBins + b

                realLBins[b] = multiArray[idxReL].floatValue
                imagLBins[b] = multiArray[idxImL].floatValue
                realRBins[b] = multiArray[idxReR].floatValue
                imagRBins[b] = multiArray[idxImR].floatValue
            }

            realLFrames.append(realLBins)
            imagLFrames.append(imagLBins)
            realRFrames.append(realRBins)
            imagRFrames.append(imagRBins)
        }

        return (realLFrames, imagLFrames, realRFrames, imagRFrames)
    }

    // MARK: - Audio Writing

    private func writeAudioBuffer(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        // Write as M4A (AAC)
        let channelCount = Int(buffer.format.channelCount)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            throw NSError(domain: "CoreMLStemSeparator", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create output format"])
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderBitRateKey: channelCount * 96000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        let audioFile = try AVAudioFile(forWriting: url, settings: settings)
        try audioFile.write(from: buffer)
    }

    // MARK: - Bundle Fallback

    /// Copies pre-bundled demo stem files as a fallback when CoreML inference fails.
    private func copyBundleFallback(audioURL: URL) throws -> [String: URL] {
        let tempDir = FileManager.default.temporaryDirectory
        var outputDictionary: [String: URL] = [:]
        let bundle = Bundle.main

        for stem in stemNames {
            var resourceName = stem.capitalized
            if stem == "bass" || stem == "piano" || stem == "other" {
                resourceName = "Others"
            }

            let stemURL = tempDir.appendingPathComponent("\(stem).m4a")

            if let bundleURL = bundle.url(forResource: resourceName, withExtension: "m4a") {
                if FileManager.default.fileExists(atPath: stemURL.path) {
                    try? FileManager.default.removeItem(at: stemURL)
                }
                do {
                    try FileManager.default.copyItem(at: bundleURL, to: stemURL)
                    outputDictionary[stem] = stemURL
                } catch {
                    print("[StemSeparator] Error copying bundle asset \(resourceName).m4a: \(error.localizedDescription)")
                    outputDictionary[stem] = stemURL
                }
            } else {
                // Last resort: copy original mixture as all stems
                if FileManager.default.fileExists(atPath: stemURL.path) {
                    try? FileManager.default.removeItem(at: stemURL)
                }
                try? FileManager.default.copyItem(at: audioURL, to: stemURL)
                outputDictionary[stem] = stemURL
            }
        }

        return outputDictionary
    }
}
