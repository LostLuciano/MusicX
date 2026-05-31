import Foundation
import AVFoundation

/// Manages multi-channel stem playback, mixing, recording, and real-time DSP effects using AVAudioEngine.
public class AudioEngineManager {
    
    private let audioEngine = AVAudioEngine()
    private let mainMixer = AVAudioMixerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    
    // Mapping of stem names to their respective player nodes
    private var players: [String: AVAudioPlayerNode] = [:]
    // Dictionary tracking local URLs for loaded stem files
    private var stemFiles: [String: URL] = [:]
    // Track loaded AVAudioFiles to support seeking
    private var audioFiles: [String: AVAudioFile] = [:]
    private var currentPosition: Double = 0.0
    
    private let stemNames = ["vocals", "drums", "bass", "guitar", "piano", "other"]
    
    public init() {
        configureAudioSession()
        setupAudioEngine()
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("AVAudioSession: Configured category to .playback for background audio.")
        } catch {
            print("AVAudioSession: Failed to set category: \(error.localizedDescription)")
        }
    }
    
    /// Initializes player nodes, attaches them to the audio engine graph, and configures mixer routing.
    private func setupAudioEngine() {
        audioEngine.attach(mainMixer)
        audioEngine.attach(timePitchNode)
        
        // Connect mainMixer to timePitchNode, and timePitchNode to outputNode
        audioEngine.connect(mainMixer, to: timePitchNode, format: nil)
        audioEngine.connect(timePitchNode, to: audioEngine.outputNode, format: nil)
        
        for name in stemNames {
            let player = AVAudioPlayerNode()
            players[name] = player
            audioEngine.attach(player)
            
            // Connect each player to the main mixer
            // format: nil lets AVAudioEngine resolve matching connections dynamically
            audioEngine.connect(player, to: mainMixer, format: nil)
        }
    }
    
    /// Loads isolated stem files into player buffers.
    /// - Parameter stems: Dictionary mapping stem names to local file system URLs.
    public func loadStemFiles(_ stems: [String: URL]) throws {
        // Skip reload if identical
        if self.stemFiles == stems && !audioFiles.isEmpty {
            print("AVAudioEngine: Stems already loaded, skipping reload.")
            return
        }
        
        self.stemFiles = stems
        self.audioFiles.removeAll()
        
        for (name, url) in stems {
            guard let player = players[name] else { continue }
            player.stop()
            
            do {
                let file = try AVAudioFile(forReading: url)
                self.audioFiles[name] = file
                print("Loaded audio file for \(name): \(url.lastPathComponent) (length: \(file.length) frames)")
            } catch {
                print("Failed to read stem file \(name): \(error.localizedDescription)")
                throw error
            }
        }
        
        // Schedule all files from the beginning
        currentPosition = 0.0
        reschedulePlayers(at: 0.0)
        
        // Prepare the engine
        audioEngine.prepare()
    }
    
    private func reschedulePlayers(at time: Double) {
        for (name, player) in players {
            player.stop() // stops playback and removes scheduled events
            
            guard let file = audioFiles[name] else { continue }
            let sampleRate = file.fileFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)
            
            if startFrame < file.length {
                let frameCount = AVAudioFrameCount(file.length - startFrame)
                player.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil, completionHandler: nil)
                print("Rescheduled \(name) from frame \(startFrame) / \(file.length) (\(frameCount) frames)")
            }
        }
    }
    
    /// Seeks all player nodes to the specified position in seconds.
    public func seek(to time: Double) {
        currentPosition = time
        let wasRunning = audioEngine.isRunning
        let isPlaying = players.values.contains { $0.isPlaying }
        
        reschedulePlayers(at: time)
        
        if wasRunning && isPlaying {
            for (_, player) in players {
                player.play()
            }
        }
    }
    
    /// Starts simultaneous playback of all loaded players.
    public func play() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        
        for (_, player) in players {
            player.play()
        }
        print("AVAudioEngine: Started simultaneous playback of all stem player nodes.")
    }
    
    /// Pauses all players.
    public func pause() {
        for (_, player) in players {
            player.pause()
        }
        print("AVAudioEngine: Paused playback.")
    }
    
    /// Stops all players and resets the audio engine.
    public func stop() {
        for (_, player) in players {
            player.stop()
        }
        audioEngine.stop()
        print("AVAudioEngine: Stopped engine graph.")
    }
    
    /// Implement setStemVolume as requested
    public func setStemVolume(stem: String, volume: Float) {
        let clampedVolume = max(0.0, min(volume, 2.0))
        
        let pathOnDisk = stemFiles[stem]?.lastPathComponent ?? "unknown"
        let isNodePlaying = players[stem]?.isPlaying ?? false
        let nodeExists = players[stem] != nil
        
        if let player = players[stem] {
            player.volume = clampedVolume
        } else {
            print("Unknown stem volume target: \(stem)")
        }
        
        // Target Fix: debug log requested
        print("""
        setStemVolume called
        stem: \(stem)
        volume: \(clampedVolume)
        node exists: \(nodeExists)
        file path: \(pathOnDisk)
        is playing: \(isNodePlaying)
        """)
    }
    
    /// Adjusts the volume slider value for a specific stem channel.
    /// - Parameters:
    ///   - stem: The identifier of the stem ("vocals", "drums", etc.)
    ///   - volume: A float value between 0.0 (silent) and 1.0 (full volume).
    public func setVolume(stem: String, volume: Float) {
        setStemVolume(stem: stem, volume: volume)
    }
    
    /// Mutes or unmutes a specific stem.
    /// - Parameters:
    ///   - stem: The identifier of the stem.
    ///   - muted: True to mute, False to restore.
    public func muteStem(_ stem: String, muted: Bool) {
        guard let player = players[stem] else { return }
        player.volume = muted ? 0.0 : 1.0
        print("AVAudioEngine: \(stem) is \(muted ? "muted" : "unmuted")")
    }
    
    /// Solos a specific stem by muting all other active channels.
    /// - Parameter stem: The identifier of the stem to isolate.
    public func soloStem(_ stem: String) {
        guard players[stem] != nil else { return }
        
        for (name, player) in players {
            if name == stem {
                player.volume = 1.0
            } else {
                player.volume = 0.0
            }
        }
        print("AVAudioEngine: Soloed \(stem) channel. All other tracks silenced.")
    }
    
    /// Adjusts the overall playback speed (tempo) without modifying pitch.
    /// - Parameter speed: Playback speed multiplier (e.g. 0.5 to 2.0).
    public func setPlaybackSpeed(_ speed: Float) {
        timePitchNode.rate = speed
        print("AVAudioEngine: Set playback speed to \(speed)")
    }
    
    /// Adjusts the overall playback pitch in semitones (-12 to +12).
    /// - Parameter semitones: Pitch offset in semitones.
    public func setPitchShift(_ semitones: Float) {
        // pitch is in cents, 1 semitone = 100 cents
        timePitchNode.pitch = semitones * 100.0
        print("AVAudioEngine: Set pitch shift to \(semitones) semitones (\(semitones * 100.0) cents)")
    }
    
    /// Extracts the audio track from a video file and writes it to a destination M4A URL.
    public func extractAudio(from videoURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AudioEngineManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"])
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        if exportSession.status == .failed {
            throw exportSession.error ?? NSError(domain: "AudioEngineManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Audio extraction failed"])
        }
        print("AVAudioEngine: Successfully extracted audio from video: \(videoURL.lastPathComponent) -> \(outputURL.lastPathComponent)")
    }
    
    /// Merges/mixes two audio files together into a single M4A file.
    public func mixAudioFiles(file1URL: URL, file2URL: URL, outputURL: URL) async throws {
        let composition = AVMutableComposition()
        
        let asset1 = AVURLAsset(url: file1URL)
        let asset2 = AVURLAsset(url: file2URL)
        
        // Wait for audio tracks to load asynchronously
        guard let audioTrack1 = try? await asset1.loadTracks(withMediaType: .audio).first,
              let audioTrack2 = try? await asset2.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioEngineManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to load audio tracks from inputs"])
        }
        
        let compTrack1 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compTrack2 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let duration1 = try await asset1.load(.duration)
        let duration2 = try await asset2.load(.duration)
        
        let timeRange1 = CMTimeRange(start: .zero, duration: duration1)
        let timeRange2 = CMTimeRange(start: .zero, duration: duration2)
        
        try compTrack1?.insertTimeRange(timeRange1, of: audioTrack1, at: .zero)
        try compTrack2?.insertTimeRange(timeRange2, of: audioTrack2, at: .zero)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AudioEngineManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession for composition"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        if exportSession.status == .failed {
            throw exportSession.error ?? NSError(domain: "AudioEngineManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mashup composition export failed"])
        }
        print("AVAudioEngine: Successfully mixed/mashup files: \(file1URL.lastPathComponent) + \(file2URL.lastPathComponent) -> \(outputURL.lastPathComponent)")
    }
    
    /// Exports the current stem mix with individual volume adjustments into a single output file using offline rendering.
    public func exportStemMix(volumes: [String: Float], outputURL: URL) async throws {
        // Stop current playing engine
        let wasRunning = audioEngine.isRunning
        if wasRunning {
            self.stop()
        }
        
        // Setup offline manual rendering mode
        let maxNumberOfFrames: AVAudioFrameCount = 4096
        
        // We need to calculate the maximum duration from loaded audio files
        var maxDuration: Double = 0.0
        for (_, file) in audioFiles {
            let duration = Double(file.length) / file.fileFormat.sampleRate
            if duration > maxDuration {
                maxDuration = duration
            }
        }
        
        guard maxDuration > 0 else {
            throw NSError(domain: "AudioEngineManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No stem audio files loaded for exporting"])
        }
        
        // Temporarily adjust volumes of players to match the export configuration
        let originalVolumes = players.mapValues { $0.volume }
        for (stem, vol) in volumes {
            if let player = players[stem] {
                player.volume = vol
            }
        }
        
        // Enable manual rendering mode
        let format = mainMixer.outputFormat(forBus: 0)
        do {
            try audioEngine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxNumberOfFrames)
        } catch {
            // Restore volumes
            for (stem, vol) in originalVolumes {
                players[stem]?.volume = vol
            }
            throw error
        }
        
        // Start engine
        try audioEngine.start()
        
        // Schedule play from beginning
        reschedulePlayers(at: 0.0)
        for (_, player) in players {
            player.play()
        }
        
        // Open output file for writing
        let settings = format.settings
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxNumberOfFrames)!
        
        var totalFramesRendered: AVAudioFramePosition = 0
        let totalFramesToRender = AVAudioFramePosition(maxDuration * format.sampleRate)
        
        while totalFramesRendered < totalFramesToRender {
            let framesToRender = min(maxNumberOfFrames, AVAudioFrameCount(totalFramesToRender - totalFramesRendered))
            let status = try audioEngine.renderOffline(framesToRender, to: buffer)
            
            switch status {
            case .success:
                try outputFile.write(from: buffer)
                totalFramesRendered += AVAudioFramePosition(framesToRender)
            case .insufficientDataFromInputNode:
                // Node had no data; continue
                break;
            case .cannotDoInCurrentContext:
                break;
            case .error:
                throw NSError(domain: "AudioEngineManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Error during offline rendering"])
            @unknown default:
                break;
            }
        }
        
        // Clean up: stop, disable manual rendering, and restore engine state
        for (_, player) in players {
            player.stop()
        }
        audioEngine.stop()
        audioEngine.disableManualRenderingMode()
        
        // Restore volumes
        for (stem, vol) in originalVolumes {
            players[stem]?.volume = vol
        }
        
        // Restart engine if it was running before
        if wasRunning {
            try? audioEngine.start()
            reschedulePlayers(at: currentPosition)
        }
    }
}
