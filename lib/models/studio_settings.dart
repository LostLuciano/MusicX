class StudioSettings {
  final int bufferSize;
  final String sampleRate;
  final String processingMode;
  final bool latencyBoost;
  final bool hardwareMonitoring;
  final bool autoSave;
  final int autoSaveInterval; // in minutes
  final bool enableMetronomeOnRecord;
  final double defaultMetronomeVolume;

  const StudioSettings({
    this.bufferSize = 256,
    this.sampleRate = '44.1 kHz',
    this.processingMode = 'Neural Engine',
    this.latencyBoost = true,
    this.hardwareMonitoring = false,
    this.autoSave = true,
    this.autoSaveInterval = 5,
    this.enableMetronomeOnRecord = false,
    this.defaultMetronomeVolume = 0.7,
  });

  factory StudioSettings.fromJson(Map<String, dynamic> json) {
    return StudioSettings(
      bufferSize: json['bufferSize'] as int? ?? 256,
      sampleRate: json['sampleRate'] as String? ?? '44.1 kHz',
      processingMode: json['processingMode'] as String? ?? 'Neural Engine',
      latencyBoost: json['latencyBoost'] as bool? ?? true,
      hardwareMonitoring: json['hardwareMonitoring'] as bool? ?? false,
      autoSave: json['autoSave'] as bool? ?? true,
      autoSaveInterval: json['autoSaveInterval'] as int? ?? 5,
      enableMetronomeOnRecord: json['enableMetronomeOnRecord'] as bool? ?? false,
      defaultMetronomeVolume: (json['defaultMetronomeVolume'] as num?)?.toDouble() ?? 0.7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bufferSize': bufferSize,
      'sampleRate': sampleRate,
      'processingMode': processingMode,
      'latencyBoost': latencyBoost,
      'hardwareMonitoring': hardwareMonitoring,
      'autoSave': autoSave,
      'autoSaveInterval': autoSaveInterval,
      'enableMetronomeOnRecord': enableMetronomeOnRecord,
      'defaultMetronomeVolume': defaultMetronomeVolume,
    };
  }

  StudioSettings copyWith({
    int? bufferSize,
    String? sampleRate,
    String? processingMode,
    bool? latencyBoost,
    bool? hardwareMonitoring,
    bool? autoSave,
    int? autoSaveInterval,
    bool? enableMetronomeOnRecord,
    double? defaultMetronomeVolume,
  }) {
    return StudioSettings(
      bufferSize: bufferSize ?? this.bufferSize,
      sampleRate: sampleRate ?? this.sampleRate,
      processingMode: processingMode ?? this.processingMode,
      latencyBoost: latencyBoost ?? this.latencyBoost,
      hardwareMonitoring: hardwareMonitoring ?? this.hardwareMonitoring,
      autoSave: autoSave ?? this.autoSave,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
      enableMetronomeOnRecord: enableMetronomeOnRecord ?? this.enableMetronomeOnRecord,
      defaultMetronomeVolume: defaultMetronomeVolume ?? this.defaultMetronomeVolume,
    );
  }
}
