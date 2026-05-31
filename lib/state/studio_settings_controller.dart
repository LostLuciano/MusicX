import 'package:flutter/foundation.dart';
import '../models/studio_settings.dart';
import '../models/model_status.dart';
import '../services/studio_settings_service.dart';
import '../services/native_ios_audio_service.dart';

class StudioSettingsController with ChangeNotifier {
  final StudioSettingsService _settingsService = StudioSettingsService();
  final NativeIosAudioService _nativeService = NativeIosAudioService();
  
  StudioSettings _settings = const StudioSettings();
  bool _isLoading = false;
  ModelsAvailability? _modelsAvailability;
  bool _isCheckingModels = false;

  StudioSettings get settings => _settings;
  bool get isLoading => _isLoading;
  ModelsAvailability? get modelsAvailability => _modelsAvailability;
  bool get isCheckingModels => _isCheckingModels;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    _settings = await _settingsService.loadSettings();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkModelsAvailability() async {
    _isCheckingModels = true;
    notifyListeners();

    try {
      final stemAvailable = await _nativeService.checkStemModelAvailability();
      final chordAvailable = await _nativeService.checkChordModelAvailability();
      final beatAvailable = await _nativeService.checkBeatModelAvailability();

      final List<ModelStatus> models = [
        ModelStatus(
          name: 'Stem Separation',
          description: 'HTDemucs 6-Stem Model',
          isAvailable: stemAvailable,
          size: stemAvailable ? '~45 MB' : null,
          version: stemAvailable ? 'v2.0.1' : null,
        ),
        ModelStatus(
          name: 'Chord Detection',
          description: 'CRNN Chord Recognition',
          isAvailable: chordAvailable,
          size: chordAvailable ? '~8 MB' : null,
          version: chordAvailable ? 'v1.0' : null,
        ),
        ModelStatus(
          name: 'Beat & Tempo',
          description: 'TCN Beat Tracking',
          isAvailable: beatAvailable,
          size: beatAvailable ? '~12 MB' : null,
          version: beatAvailable ? 'v1.0' : null,
        ),
      ];

      _modelsAvailability = ModelsAvailability(
        stemSeparationAvailable: stemAvailable,
        chordDetectionAvailable: chordAvailable,
        beatDetectionAvailable: beatAvailable,
        models: models,
      );
    } catch (e) {
      debugPrint('Error checking models: $e');
      _modelsAvailability = const ModelsAvailability(
        stemSeparationAvailable: false,
        chordDetectionAvailable: false,
        beatDetectionAvailable: false,
        models: [],
      );
    }

    _isCheckingModels = false;
    notifyListeners();
  }

  Future<void> updateBufferSize(int bufferSize) async {
    _settings = _settings.copyWith(bufferSize: bufferSize);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateSampleRate(String sampleRate) async {
    _settings = _settings.copyWith(sampleRate: sampleRate);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateProcessingMode(String mode) async {
    _settings = _settings.copyWith(processingMode: mode);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateLatencyBoost(bool enabled) async {
    _settings = _settings.copyWith(latencyBoost: enabled);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateHardwareMonitoring(bool enabled) async {
    _settings = _settings.copyWith(hardwareMonitoring: enabled);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateAutoSave(bool enabled) async {
    _settings = _settings.copyWith(autoSave: enabled);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateAutoSaveInterval(int minutes) async {
    _settings = _settings.copyWith(autoSaveInterval: minutes);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateEnableMetronomeOnRecord(bool enabled) async {
    _settings = _settings.copyWith(enableMetronomeOnRecord: enabled);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateDefaultMetronomeVolume(double volume) async {
    _settings = _settings.copyWith(defaultMetronomeVolume: volume);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateThemeColor(int colorValue) async {
    _settings = _settings.copyWith(themeColorValue: colorValue);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateUIStyle(int styleIndex) async {
    _settings = _settings.copyWith(uiStyle: styleIndex);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  // ── Glass Settings ────────────────────────────────────────────────
  Future<void> updateGlassRefractionMode(int mode) async {
    _settings = _settings.copyWith(glassRefractionMode: mode);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassDisplacement(double v) async {
    _settings = _settings.copyWith(glassDisplacement: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassBlur(double v) async {
    _settings = _settings.copyWith(glassBlur: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassSaturation(double v) async {
    _settings = _settings.copyWith(glassSaturation: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassChromaticAb(double v) async {
    _settings = _settings.copyWith(glassChromaticAb: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassElasticity(double v) async {
    _settings = _settings.copyWith(glassElasticity: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassCornerRadius(double v) async {
    _settings = _settings.copyWith(glassCornerRadius: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGlassOverLight(bool v) async {
    _settings = _settings.copyWith(glassOverLight: v);
    await _settingsService.saveSettings(_settings);
    notifyListeners();
  }


  Future<void> resetToDefaults() async {
    await _settingsService.resetToDefaults();
    _settings = const StudioSettings();
    notifyListeners();
  }
}
