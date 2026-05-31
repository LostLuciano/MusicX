import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';

class NativeIosAudioService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.methodChannelName,
  );

  static final StreamController<Map<String, dynamic>> _separationProgressController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get separationProgressStream =>
      _separationProgressController.stream;

  NativeIosAudioService() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'onSeparationProgress':
        final log = call.arguments['log'] as String? ?? '';
        final progress = (call.arguments['progress'] as num?)?.toDouble() ?? 0.0;
        _separationProgressController.add({'log': log, 'progress': progress});
        break;
    }
  }

  Future<String?> importAudio() async {
    try {
      final String? path = await _channel.invokeMethod<String>('importAudio');
      return path ?? 'placeholder_mixture.mp3';
    } catch (e) {
      debugPrint('Native importAudio unavailable, using web fallback: $e');
      return 'placeholder_mixture.mp3';
    }
  }

  Future<String?> startRecording() async {
    try {
      final String? path = await _channel.invokeMethod<String>(
        'startRecording',
      );
      return path ?? 'placeholder_recording.wav';
    } catch (e) {
      debugPrint('Native startRecording unavailable, using web fallback: $e');
      return 'placeholder_recording.wav';
    }
  }

  Future<String?> stopRecording() async {
    try {
      final String? path = await _channel.invokeMethod<String>('stopRecording');
      return path;
    } catch (e) {
      debugPrint('Native stopRecording unavailable, using web fallback: $e');
      return null;
    }
  }

  Future<Map<String, String>> separateStems(String audioPath, {String? processingMode, String? modelQuality}) async {
    try {
      final Map? result = await _channel.invokeMethod<Map>('separateStems', {
        'audioPath': audioPath,
        'processingMode': processingMode,
        'modelQuality': modelQuality,
      });
      if (result != null) {
        return result.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      return _placeholderStems();
    } catch (e) {
      debugPrint('Native separateStems unavailable, using web fallback: $e');
      return _placeholderStems();
    }
  }

  Future<List<Map<String, dynamic>>> analyzeChords(String audioPath) async {
    try {
      final List? result = await _channel.invokeMethod<List>('analyzeChords', {
        'audioPath': audioPath,
      });
      if (result != null) {
        return result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return _placeholderChords();
    } catch (e) {
      debugPrint('Native analyzeChords unavailable, using web fallback: $e');
      return _placeholderChords();
    }
  }

  Future<Map<String, dynamic>> analyzeBeatsAndTempo(String audioPath) async {
    try {
      final Map? result = await _channel.invokeMethod<Map>(
        'analyzeBeatsAndTempo',
        {'audioPath': audioPath},
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return _placeholderBeats();
    } catch (e) {
      debugPrint(
        'Native analyzeBeatsAndTempo unavailable, using web fallback: $e',
      );
      return _placeholderBeats();
    }
  }

  Future<void> playStemMix(Map<String, String> stemPaths, {double positionSeconds = 0.0}) async {
    try {
      await _channel.invokeMethod('playStemMix', {
        'stemPaths': stemPaths,
        'position': positionSeconds,
      });
    } catch (e) {
      debugPrint('Native playStemMix unavailable, using web fallback: $e');
    }
  }

  Future<void> seekStemMix(double positionSeconds) async {
    try {
      await _channel.invokeMethod('seekStemMix', {'position': positionSeconds});
    } catch (e) {
      debugPrint('Native seekStemMix unavailable, using web fallback: $e');
    }
  }

  Future<void> pauseStemMix() async {
    try {
      await _channel.invokeMethod('pauseStemMix');
    } catch (e) {
      debugPrint('Native pauseStemMix unavailable, using web fallback: $e');
    }
  }

  Future<void> stopStemMix() async {
    try {
      await _channel.invokeMethod('stopStemMix');
    } catch (e) {
      debugPrint('Native stopStemMix unavailable, using web fallback: $e');
    }
  }

  Future<void> setStemVolume(String stem, double volume) async {
    try {
      await _channel.invokeMethod('setStemVolume', {
        'stem': stem,
        'volume': volume,
      });
    } catch (e) {
      debugPrint('Native setStemVolume unavailable, using web fallback: $e');
    }
  }

  Future<void> muteStem(String stemName, bool muted) async {
    try {
      await _channel.invokeMethod('muteStem', {
        'stemName': stemName,
        'muted': muted,
      });
    } catch (e) {
      debugPrint('Native muteStem unavailable, using web fallback: $e');
    }
  }

  Future<void> soloStem(String stemName) async {
    try {
      await _channel.invokeMethod('soloStem', {'stemName': stemName});
    } catch (e) {
      debugPrint('Native soloStem unavailable, using web fallback: $e');
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _channel.invokeMethod('setPlaybackSpeed', {'speed': speed});
    } catch (e) {
      debugPrint('Native setPlaybackSpeed unavailable, using web fallback: $e');
    }
  }

  Future<void> setPitchShift(double pitch) async {
    try {
      await _channel.invokeMethod('setPitchShift', {'pitch': pitch});
    } catch (e) {
      debugPrint('Native setPitchShift unavailable: $e');
    }
  }

  Future<String?> extractAudioFromVideo(String videoPath, String outputPath) async {
    try {
      final String? path = await _channel.invokeMethod<String>('extractAudioFromVideo', {
        'videoPath': videoPath,
        'outputPath': outputPath,
      });
      return path;
    } catch (e) {
      debugPrint('Native extractAudioFromVideo failed: $e');
      return null;
    }
  }

  Future<String?> mixAudioFiles(String file1Path, String file2Path, String outputPath) async {
    try {
      final String? path = await _channel.invokeMethod<String>('mixAudioFiles', {
        'file1Path': file1Path,
        'file2Path': file2Path,
        'outputPath': outputPath,
      });
      return path;
    } catch (e) {
      debugPrint('Native mixAudioFiles failed: $e');
      return null;
    }
  }

  Future<String?> exportStemMix(Map<String, double> volumes, String outputPath) async {
    try {
      final String? path = await _channel.invokeMethod<String>('exportStemMix', {
        'volumes': volumes,
        'outputPath': outputPath,
      });
      return path;
    } catch (e) {
      debugPrint('Native exportStemMix failed: $e');
      return null;
    }
  }

  Future<void> shareFile(String filePath) async {
    try {
      await _channel.invokeMethod('shareFile', {'filePath': filePath});
    } catch (e) {
      debugPrint('Native shareFile failed: $e');
    }
  }

  Future<List<double>?> getWaveformData(String audioPath, {int binsCount = 100}) async {
    try {
      final List? result = await _channel.invokeMethod<List>('getWaveformData', {
        'audioPath': audioPath,
        'binsCount': binsCount,
      });
      if (result != null) {
        return result.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Native getWaveformData failed/unavailable: $e');
      return null;
    }
  }

  // --- Model Availability Checks ---

  Future<bool> checkStemModelAvailability() async {
    try {
      final bool? available = await _channel.invokeMethod<bool>('checkStemModelAvailability');
      return available ?? false;
    } catch (e) {
      debugPrint('Native checkStemModelAvailability failed: $e');
      return false;
    }
  }

  Future<bool> checkChordModelAvailability() async {
    try {
      final bool? available = await _channel.invokeMethod<bool>('checkChordModelAvailability');
      return available ?? false;
    } catch (e) {
      debugPrint('Native checkChordModelAvailability failed: $e');
      return false;
    }
  }

  Future<bool> checkBeatModelAvailability() async {
    try {
      final bool? available = await _channel.invokeMethod<bool>('checkBeatModelAvailability');
      return available ?? false;
    } catch (e) {
      debugPrint('Native checkBeatModelAvailability failed: $e');
      return false;
    }
  }

  // --- Metronome ---

  Future<void> startMetronome({
    double bpm = 120.0,
    int beatsPerBar = 4,
    int subdivisions = 1,
  }) async {
    try {
      await _channel.invokeMethod('startMetronome', {
        'bpm': bpm,
        'beatsPerBar': beatsPerBar,
        'subdivisions': subdivisions,
      });
    } catch (e) {
      debugPrint('Native startMetronome failed: $e');
    }
  }

  Future<void> stopMetronome() async {
    try {
      await _channel.invokeMethod('stopMetronome');
    } catch (e) {
      debugPrint('Native stopMetronome failed: $e');
    }
  }

  Future<void> setMetronomeVolume(double volume) async {
    try {
      await _channel.invokeMethod('setMetronomeVolume', {'volume': volume});
    } catch (e) {
      debugPrint('Native setMetronomeVolume failed: $e');
    }
  }

  Future<void> updateMetronomeBPM(double bpm) async {
    try {
      await _channel.invokeMethod('updateMetronomeBPM', {'bpm': bpm});
    } catch (e) {
      debugPrint('Native updateMetronomeBPM failed: $e');
    }
  }

  // --- Lyrics ---

  Future<List<Map<String, dynamic>>> loadLyrics(String songName) async {
    try {
      final List? result = await _channel.invokeMethod<List>(
        'loadLyrics',
        {'songName': songName},
      );
      if (result != null) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Native loadLyrics failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLyricAt(double timeSeconds) async {
    try {
      final Map? result = await _channel.invokeMethod<Map>(
        'getLyricAt',
        {'time': timeSeconds},
      );
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('Native getLyricAt failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllLyrics() async {
    try {
      final List? result = await _channel.invokeMethod<List>('getAllLyrics');
      if (result != null) {
        return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Native getAllLyrics failed: $e');
      return [];
    }
  }

  // --- Fallback Placeholders ---

  Map<String, String> _placeholderStems() {
    return {
      'vocals': 'placeholder_vocals.wav',
      'drums': 'placeholder_drums.wav',
      'bass': 'placeholder_bass.wav',
      'guitar': 'placeholder_guitar.wav',
      'piano': 'placeholder_piano.wav',
      'other': 'placeholder_other.wav',
    };
  }

  List<Map<String, dynamic>> _placeholderChords() {
    return [
      {
        'name': 'C:maj',
        'startTime': 0.0,
        'endTime': 4.2,
        'rootNote': 0,
        'chordType': 1,
      },
      {
        'name': 'G:maj',
        'startTime': 4.2,
        'endTime': 8.5,
        'rootNote': 7,
        'chordType': 1,
      },
      {
        'name': 'A:min',
        'startTime': 8.5,
        'endTime': 12.8,
        'rootNote': 9,
        'chordType': 2,
      },
      {
        'name': 'F:maj',
        'startTime': 12.8,
        'endTime': 16.4,
        'rootNote': 5,
        'chordType': 1,
      },
    ];
  }

  Map<String, dynamic> _placeholderBeats() {
    return {
      'tempo': 120.0,
      'beats': [
        {'time': 0.0, 'index': 0},
        {'time': 0.5, 'index': 1},
        {'time': 1.0, 'index': 2},
        {'time': 1.5, 'index': 3},
        {'time': 2.0, 'index': 0},
        {'time': 2.5, 'index': 1},
        {'time': 3.0, 'index': 2},
        {'time': 3.5, 'index': 3},
      ],
      'downbeats': [0.0, 2.0],
    };
  }
}
