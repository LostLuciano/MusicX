import Foundation
import Flutter
import UIKit
import AVFoundation

/// Native iOS entry point bridging requests from Flutter Dart UI code.
public class FlutterMethodChannelBridge: NSObject {
    
    private let channelName = "music_stem_studio/native_audio"
    private var channel: FlutterMethodChannel?
    
    // Core managers
    private let separator = CoreMLStemSeparator()
    private let audioEngine = AudioEngineManager()
    private let chordDetector = ChordDetectionManager()
    private let beatDetector = BeatDetectionManager()
    private let metronome = MetronomeManager()
    private let lyricsManager = LyricsManager()
    
    public func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        self.channel = channel
        registrar.addMethodCallDelegate(self, channel: channel)
    }
    
    private func extractWaveformData(audioURL: URL, binsCount: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let totalFrames = Int(file.length)
        guard totalFrames > 0 else { return [] }
        
        let framesPerBin = max(1, totalFrames / binsCount)
        var amplitudes = [Float]()
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(framesPerBin)) else {
            throw NSError(domain: "AudioEngineError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate AVAudioPCMBuffer"])
        }
        
        for bin in 0..<binsCount {
            let startFrame = bin * framesPerBin
            if startFrame >= totalFrames {
                amplitudes.append(0.0)
                continue
            }
            
            file.framePosition = AVAudioFramePosition(startFrame)
            let framesToRead = min(AVAudioFrameCount(framesPerBin), AVAudioFrameCount(totalFrames - startFrame))
            
            do {
                try file.read(into: buffer, frameCount: framesToRead)
                
                var maxVal: Float = 0.0
                if let floatData = buffer.floatChannelData?[0] {
                    var sum: Float = 0.0
                    let count = Int(framesToRead)
                    if count > 0 {
                        for i in 0..<count {
                            let sample = floatData[i]
                            sum += sample * sample
                        }
                        let rms = sqrt(sum / Float(count))
                        maxVal = rms
                    }
                }
                amplitudes.append(maxVal)
            } catch {
                amplitudes.append(0.0)
            }
        }
        
        let maxAmp = amplitudes.max() ?? 0.0
        if maxAmp > 0.001 {
            amplitudes = amplitudes.map { $0 / maxAmp }
        } else {
            amplitudes = Array(repeating: 0.1, count: binsCount)
        }
        
        return amplitudes
    }
}

extension FlutterMethodChannelBridge: FlutterPlugin {
    
    public static func register(with registrar: any FlutterPluginRegistrar) {
        let bridge = FlutterMethodChannelBridge()
        bridge.register(with: registrar)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        
        switch call.method {
        case "importAudio":
            // Placeholder: simulate choosing a track
            result("/var/mobile/Containers/Data/Documents/imported_mixture.mp3")
            
        case "startRecording":
            result("/var/mobile/Containers/Data/Documents/recording.wav")
            
        case "stopRecording":
            result(nil)
            
        case "separateStems":
            guard let args = arguments, let audioPath = args["audioPath"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "audioPath is required", details: nil))
                return
            }
            
            let processingMode = arguments?["processingMode"] as? String
            let modelQuality = arguments?["modelQuality"] as? String
            let audioURL = URL(fileURLWithPath: audioPath)
            
            Task {
                do {
                    let stemURLs = try await separator.separate(audioURL: audioURL, processingMode: processingMode, modelQuality: modelQuality) { [weak self] (log, progress) in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            self.channel?.invokeMethod("onSeparationProgress", arguments: [
                                "log": log,
                                "progress": progress
                            ])
                        }
                    }
                    // Map local URLs to absolute path strings to pass back to Dart
                    var pathsDict: [String: String] = [:]
                    for (key, val) in stemURLs {
                        pathsDict[key] = val.path
                    }
                    
                    // Load the files directly to our audio player mixer
                    try audioEngine.loadStemFiles(stemURLs)
                    
                    DispatchQueue.main.async {
                        result(pathsDict)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SEPARATION_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "analyzeChords":
            guard let args = arguments, let audioPath = args["audioPath"] as? String else {
                print("[NativeBridge] analyzeChords: ERROR - MISSING_ARGUMENT (audioPath is required)")
                result(FlutterError(code: "MISSING_ARGUMENT", message: "audioPath is required", details: nil))
                return
            }
            
            let audioURL = URL(fileURLWithPath: audioPath)
            print("[NativeBridge] analyzeChords: Started chord detection analysis for \(audioURL.lastPathComponent)")
            
            Task {
                do {
                    let segments = try await chordDetector.analyzeChords(audioURL: audioURL)
                    print("[NativeBridge] analyzeChords: Successfully detected \(segments.count) segments.")
                    
                    // Log first 5 segments for debugging normalization
                    for (index, segment) in segments.prefix(5).enumerated() {
                        print("  Segment \(index): time=\(segment.startTime)-\(segment.endTime)s, chord=\(segment.name)")
                    }
                    
                    // Convert Codable segments to dictionary arrays
                    if let data = try? JSONEncoder().encode(segments),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        print("[NativeBridge] analyzeChords: Encoded segments to JSON dictionary successfully.")
                        DispatchQueue.main.async {
                            result(json)
                        }
                    } else {
                        print("[NativeBridge] analyzeChords: WARNING - JSON serialization failed, returning empty array")
                        DispatchQueue.main.async {
                            result([])
                        }
                    }
                } catch {
                    print("[NativeBridge] analyzeChords: ERROR - analysis failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CHORD_ANALYSIS_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "analyzeBeatsAndTempo":
            guard let args = arguments, let audioPath = args["audioPath"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "audioPath is required", details: nil))
                return
            }
            
            let audioURL = URL(fileURLWithPath: audioPath)
            
            Task {
                do {
                    let beatResult = try await beatDetector.analyzeBeats(audioURL: audioURL)
                    
                    if let data = try? JSONEncoder().encode(beatResult),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        DispatchQueue.main.async {
                            result(json)
                        }
                    } else {
                        DispatchQueue.main.async {
                            result(nil)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "BEAT_ANALYSIS_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "playStemMix":
            if let args = arguments, let stemPaths = args["stemPaths"] as? [String: String] {
                var stemURLs: [String: URL] = [:]
                for (key, path) in stemPaths {
                    if !path.isEmpty {
                        stemURLs[key] = URL(fileURLWithPath: path)
                    }
                }
                do {
                    try audioEngine.loadStemFiles(stemURLs)
                } catch {
                    result(FlutterError(code: "LOAD_FAILED", message: "Failed to load stem files in playStemMix: \(error.localizedDescription)", details: nil))
                    return
                }
            }
            
            if let pos = arguments?["position"] as? Double {
                audioEngine.seek(to: pos)
            }
            
            do {
                try audioEngine.play()
                result(nil)
            } catch {
                result(FlutterError(code: "PLAYBACK_FAILED", message: error.localizedDescription, details: nil))
            }
            
        case "seekStemMix":
            guard let args = arguments, let position = args["position"] as? Double else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "position is required", details: nil))
                return
            }
            audioEngine.seek(to: position)
            result(nil)
            
        case "pauseStemMix":
            audioEngine.pause()
            result(nil)
            
        case "stopStemMix":
            audioEngine.stop()
            result(nil)
            
        case "setStemVolume":
            guard let args = arguments,
                  let stem = args["stem"] as? String,
                  let volume = args["volume"] as? Double else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "stem and volume are required",
                    details: nil
                ))
                return
            }
            audioEngine.setStemVolume(stem: stem, volume: Float(volume))
            result(true)
            
        case "muteStem":
            guard let args = arguments,
                  let stemName = args["stemName"] as? String,
                  let muted = args["muted"] as? Bool else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "stemName and muted are required", details: nil))
                return
            }
            audioEngine.muteStem(stemName, muted: muted)
            result(nil)
            
        case "soloStem":
            guard let args = arguments, let stemName = args["stemName"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "stemName is required", details: nil))
                return
            }
            audioEngine.soloStem(stemName)
            result(nil)
            
        case "setPlaybackSpeed":
            guard let args = arguments, let speed = args["speed"] as? Double else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "speed is required", details: nil))
                return
            }
            audioEngine.setPlaybackSpeed(Float(speed))
            result(nil)
            
        case "setPitchShift":
            guard let args = arguments, let pitch = args["pitch"] as? Double else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "pitch is required", details: nil))
                return
            }
            audioEngine.setPitchShift(Float(pitch))
            result(nil)
            
        case "extractAudioFromVideo":
            guard let args = arguments,
                  let videoPath = args["videoPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "videoPath and outputPath are required", details: nil))
                return
            }
            let videoURL = URL(fileURLWithPath: videoPath)
            let outputURL = URL(fileURLWithPath: outputPath)
            
            Task {
                do {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    try await audioEngine.extractAudio(from: videoURL, outputURL: outputURL)
                    DispatchQueue.main.async {
                        result(outputURL.path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "mixAudioFiles":
            guard let args = arguments,
                  let file1Path = args["file1Path"] as? String,
                  let file2Path = args["file2Path"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "file1Path, file2Path and outputPath are required", details: nil))
                return
            }
            let file1URL = URL(fileURLWithPath: file1Path)
            let file2URL = URL(fileURLWithPath: file2Path)
            let outputURL = URL(fileURLWithPath: outputPath)
            
            Task {
                do {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    try await audioEngine.mixAudioFiles(file1URL: file1URL, file2URL: file2URL, outputURL: outputURL)
                    DispatchQueue.main.async {
                        result(outputURL.path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "MIXING_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "exportStemMix":
            guard let args = arguments,
                  let volumes = args["volumes"] as? [String: Double],
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "volumes and outputPath are required", details: nil))
                return
            }
            let outputURL = URL(fileURLWithPath: outputPath)
            var floatVolumes: [String: Float] = [:]
            for (key, val) in volumes {
                floatVolumes[key] = Float(val)
            }
            Task {
                do {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    try await audioEngine.exportStemMix(volumes: floatVolumes, outputURL: outputURL)
                    DispatchQueue.main.async {
                        result(outputURL.path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "EXPORT_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "shareFile":
            guard let args = arguments, let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "filePath is required", details: nil))
                return
            }
            let fileURL = URL(fileURLWithPath: filePath)
            
            DispatchQueue.main.async {
                // Get the top-most view controller to present UIActivityViewController using modern UIWindowScene API
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                      let rootVC = window.rootViewController else {
                    result(FlutterError(code: "NO_ROOT_VC", message: "Could not find root view controller", details: nil))
                    return
                }
                
                var topVC = rootVC
                while let presentedVC = topVC.presentedViewController {
                    topVC = presentedVC
                }
                
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = topVC.view
                    popoverController.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                topVC.present(activityVC, animated: true, completion: {
                    result(nil)
                })
            }
            
        case "getWaveformData":
            guard let args = arguments,
                  let audioPath = args["audioPath"] as? String,
                  let binsCount = args["binsCount"] as? Int else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "audioPath and binsCount are required", details: nil))
                return
            }
            
            let audioURL = URL(fileURLWithPath: audioPath)
            
            Task {
                do {
                    let waveform = try self.extractWaveformData(audioURL: audioURL, binsCount: binsCount)
                    DispatchQueue.main.async {
                        result(waveform)
                    }
                } catch {
                    print("[NativeBridge] getWaveformData: Error - \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        result(FlutterError(code: "WAVEFORM_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            
        case "startMetronome":
            let bpm   = (arguments?["bpm"]          as? Double) ?? 120.0
            let beats = (arguments?["beatsPerBar"]  as? Int)    ?? 4
            let subs  = (arguments?["subdivisions"] as? Int)    ?? 1
            metronome.start(bpm: bpm, beatsPerBar: beats, subdivisions: subs)
            result(nil)
            
        case "stopMetronome":
            metronome.stop()
            result(nil)
            
        case "updateMetronomeBPM":
            guard let args = arguments, let bpm = args["bpm"] as? Double else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "bpm is required", details: nil))
                return
            }
            metronome.updateBPM(bpm)
            result(nil)
            
        case "setMetronomeVolume":
            guard let args = arguments, let volume = args["volume"] as? Double else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "volume is required", details: nil))
                return
            }
            metronome.setVolume(Float(volume))
            result(nil)
            
        case "loadLyrics":
            guard let args = arguments, let songName = args["songName"] as? String else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "songName is required", details: nil))
                return
            }
            let found = lyricsManager.loadLyrics(for: songName)
            result(found ? lyricsManager.toSerializable() : [])
            
        case "getLyricAt":
            guard let args = arguments, let time = args["time"] as? Double else {
                result(FlutterError(code: "MISSING_ARGUMENT", message: "time is required", details: nil))
                return
            }
            if let line = lyricsManager.activeLine(at: time) {
                result(["startTime": line.startTime, "endTime": line.endTime, "text": line.text])
            } else {
                result(nil)
            }
            
        case "getAllLyrics":
            result(lyricsManager.toSerializable())
            
        case "checkStemModelAvailability":
            // Check if stem separation models are available in bundle
            let stemModels = [
                "dun_tfc_tdf_b9_l3_w_6stems_32_fp32_v2.0.1",
                "dunlight_tfc_tdf_b9_l3_w_subv1_cirm_6stems_64_fp16_v2.0.0"
            ]
            var available = false
            for modelName in stemModels {
                if let _ = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                    available = true
                    break
                }
            }
            result(available)
            
        case "checkChordModelAvailability":
            // Check if chord detection model is available
            if let _ = Bundle.main.url(forResource: "Chordcrnn", withExtension: "mlmodelc") {
                result(true)
            } else {
                result(false)
            }
            
        case "checkBeatModelAvailability":
            // Check if beat detection model is available
            if let _ = Bundle.main.url(forResource: "convtcn20_2048_fp16", withExtension: "mlmodelc") {
                result(true)
            } else {
                result(false)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
