import 'package:flutter/foundation.dart';
import '../models/audio_project.dart';
import 'native_ios_audio_service.dart';

class StemSeparationService with ChangeNotifier {
  AnalysisStatus _status = AnalysisStatus.unavailable;
  bool _modelAvailable = false;
  String? _errorMessage;

  AnalysisStatus get status => _status;
  bool get modelAvailable => _modelAvailable;
  String? get errorMessage => _errorMessage;

  Future<void> checkModelAvailability() async {
    try {
      final nativeService = NativeIosAudioService();
      _modelAvailable = await nativeService.checkStemModelAvailability();
      
      if (_modelAvailable) {
        _status = AnalysisStatus.ready;
        _errorMessage = null;
      } else {
        _status = AnalysisStatus.waitingModel;
        _errorMessage = 'Model AI stem separation belum tersedia. Pastikan model CoreML sudah diintegrasikan ke dalam build.';
      }
    } catch (e) {
      debugPrint('Error checking stem model: $e');
      _status = AnalysisStatus.unavailable;
      _errorMessage = 'Tidak dapat memeriksa ketersediaan model: $e';
    }
    notifyListeners();
  }

  Future<StemFiles?> processSeparation(AudioProject project) async {
    if (project.originalAudioPath == null) {
      _errorMessage = 'Tidak ada file audio untuk diproses';
      _status = AnalysisStatus.error;
      notifyListeners();
      return null;
    }

    _status = AnalysisStatus.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      final nativeService = NativeIosAudioService();
      
      // Check if model is available first
      final available = await nativeService.checkStemModelAvailability();
      if (!available) {
        _status = AnalysisStatus.waitingModel;
        _errorMessage = 'Model AI belum tersedia. Silakan integrasikan model CoreML terlebih dahulu.';
        notifyListeners();
        return null;
      }

      // Process stem separation
      final stemPaths = await nativeService.separateStems(project.originalAudioPath!);
      
      if (stemPaths.isEmpty) {
        _status = AnalysisStatus.error;
        _errorMessage = 'Gagal memisahkan stems. Tidak ada output yang dihasilkan.';
        notifyListeners();
        return null;
      }

      final stemFiles = StemFiles(
        vocals: stemPaths['vocals'],
        bass: stemPaths['bass'],
        drums: stemPaths['drums'],
        piano: stemPaths['piano'],
        guitar: stemPaths['guitar'],
        other: stemPaths['other'],
      );

      _status = AnalysisStatus.ready;
      _errorMessage = null;
      notifyListeners();
      return stemFiles;
    } catch (e) {
      debugPrint('Stem Separation processing failed: $e');
      _status = AnalysisStatus.error;
      _errorMessage = 'Error saat memproses: $e';
      notifyListeners();
      return null;
    }
  }

  void setStatus(AnalysisStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
