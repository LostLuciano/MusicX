import 'package:flutter/foundation.dart';
import '../models/audio_project.dart';
import 'native_ios_audio_service.dart';

class AnalysisService with ChangeNotifier {
  AnalysisStatus _chordStatus = AnalysisStatus.unavailable;
  AnalysisStatus _beatStatus = AnalysisStatus.unavailable;
  bool _chordModelAvailable = false;
  bool _beatModelAvailable = false;
  String? _chordErrorMessage;
  String? _beatErrorMessage;

  AnalysisStatus get chordStatus => _chordStatus;
  AnalysisStatus get beatStatus => _beatStatus;
  bool get chordModelAvailable => _chordModelAvailable;
  bool get beatModelAvailable => _beatModelAvailable;
  String? get chordErrorMessage => _chordErrorMessage;
  String? get beatErrorMessage => _beatErrorMessage;

  Future<void> checkModelAvailability() async {
    try {
      final nativeService = NativeIosAudioService();
      _chordModelAvailable = await nativeService.checkChordModelAvailability();
      _beatModelAvailable = await nativeService.checkBeatModelAvailability();
      
      if (_chordModelAvailable) {
        _chordStatus = AnalysisStatus.ready;
        _chordErrorMessage = null;
      } else {
        _chordStatus = AnalysisStatus.waitingModel;
        _chordErrorMessage = 'Model AI chord detection belum tersedia.';
      }

      if (_beatModelAvailable) {
        _beatStatus = AnalysisStatus.ready;
        _beatErrorMessage = null;
      } else {
        _beatStatus = AnalysisStatus.waitingModel;
        _beatErrorMessage = 'Model AI beat detection belum tersedia.';
      }
    } catch (e) {
      debugPrint('Error checking analysis models: $e');
      _chordStatus = AnalysisStatus.unavailable;
      _beatStatus = AnalysisStatus.unavailable;
      _chordErrorMessage = 'Tidak dapat memeriksa model chord: $e';
      _beatErrorMessage = 'Tidak dapat memeriksa model beat: $e';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> analyzeChordAndTempo(
    AudioProject project,
  ) async {
    if (project.originalAudioPath == null) {
      _chordErrorMessage = 'Tidak ada file audio untuk dianalisis';
      _beatErrorMessage = 'Tidak ada file audio untuk dianalisis';
      _chordStatus = AnalysisStatus.error;
      _beatStatus = AnalysisStatus.error;
      notifyListeners();
      return null;
    }

    _chordStatus = AnalysisStatus.processing;
    _beatStatus = AnalysisStatus.processing;
    _chordErrorMessage = null;
    _beatErrorMessage = null;
    notifyListeners();

    try {
      final nativeService = NativeIosAudioService();
      
      // Check model availability
      final chordAvailable = await nativeService.checkChordModelAvailability();
      final beatAvailable = await nativeService.checkBeatModelAvailability();

      Map<String, dynamic> result = {};

      // Analyze chords if model available
      if (chordAvailable) {
        try {
          final chordData = await nativeService.analyzeChords(project.originalAudioPath!);
          result['chords'] = chordData;
          _chordStatus = AnalysisStatus.ready;
          _chordErrorMessage = null;
        } catch (e) {
          debugPrint('Chord analysis failed: $e');
          _chordStatus = AnalysisStatus.error;
          _chordErrorMessage = 'Error analisis chord: $e';
        }
      } else {
        _chordStatus = AnalysisStatus.waitingModel;
        _chordErrorMessage = 'Model chord detection belum tersedia';
      }

      // Analyze beats if model available
      if (beatAvailable) {
        try {
          final beatData = await nativeService.analyzeBeatsAndTempo(project.originalAudioPath!);
          result['beats'] = beatData;
          _beatStatus = AnalysisStatus.ready;
          _beatErrorMessage = null;
        } catch (e) {
          debugPrint('Beat analysis failed: $e');
          _beatStatus = AnalysisStatus.error;
          _beatErrorMessage = 'Error analisis beat: $e';
        }
      } else {
        _beatStatus = AnalysisStatus.waitingModel;
        _beatErrorMessage = 'Model beat detection belum tersedia';
      }

      notifyListeners();
      return result.isNotEmpty ? result : null;
    } catch (e) {
      debugPrint('Analysis processing failed: $e');
      _chordStatus = AnalysisStatus.error;
      _beatStatus = AnalysisStatus.error;
      _chordErrorMessage = 'Error umum: $e';
      _beatErrorMessage = 'Error umum: $e';
      notifyListeners();
      return null;
    }
  }

  void setStatuses({AnalysisStatus? chord, AnalysisStatus? beat}) {
    if (chord != null) _chordStatus = chord;
    if (beat != null) _beatStatus = beat;
    notifyListeners();
  }

  void clearErrors() {
    _chordErrorMessage = null;
    _beatErrorMessage = null;
    notifyListeners();
  }
}
