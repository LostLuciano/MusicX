// 0 = Spotify-Dark, 1 = Apple Music-Glass
enum AppUIStyle { spotify, appleMusic }

// Refraction calculation method for glass effect
enum GlassRefractionMode { standard, polar, prominent }

class StudioSettings {
  final int bufferSize;
  final String sampleRate;
  final String processingMode;
  final bool latencyBoost;
  final bool hardwareMonitoring;
  final bool autoSave;
  final int autoSaveInterval;
  final bool enableMetronomeOnRecord;
  final double defaultMetronomeVolume;
  final int themeColorValue;
  final int uiStyle; // 0=Spotify, 1=AppleMusic

  // ── Glassy Boi Glass Settings ─────────────────────────────────────
  final int glassRefractionMode;     // 0=Standard, 1=Polar, 2=Prominent
  final double glassDisplacement;    // 0–200,  default 100
  final double glassBlur;            // 0–5,    default 0.5
  final double glassSaturation;      // 100–200 (%), default 140
  final double glassChromaticAb;     // 0–10,   default 2
  final double glassElasticity;      // 0–1,    default 0.65
  final double glassCornerRadius;    // 4–64,   default 32
  final bool   glassOverLight;       // dark tint for light backgrounds

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
    this.themeColorValue = 0xFF9D4EDD,
    this.uiStyle = 0,
    // Glass defaults
    this.glassRefractionMode = 0,
    this.glassDisplacement = 100,
    this.glassBlur = 0.5,
    this.glassSaturation = 140,
    this.glassChromaticAb = 2,
    this.glassElasticity = 0.65,
    this.glassCornerRadius = 32,
    this.glassOverLight = false,
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
      themeColorValue: json['themeColorValue'] as int? ?? 0xFF9D4EDD,
      uiStyle: json['uiStyle'] as int? ?? 0,
      glassRefractionMode: json['glassRefractionMode'] as int? ?? 0,
      glassDisplacement: (json['glassDisplacement'] as num?)?.toDouble() ?? 100,
      glassBlur: (json['glassBlur'] as num?)?.toDouble() ?? 0.5,
      glassSaturation: (json['glassSaturation'] as num?)?.toDouble() ?? 140,
      glassChromaticAb: (json['glassChromaticAb'] as num?)?.toDouble() ?? 2,
      glassElasticity: (json['glassElasticity'] as num?)?.toDouble() ?? 0.65,
      glassCornerRadius: (json['glassCornerRadius'] as num?)?.toDouble() ?? 32,
      glassOverLight: json['glassOverLight'] as bool? ?? false,
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
      'themeColorValue': themeColorValue,
      'uiStyle': uiStyle,
      'glassRefractionMode': glassRefractionMode,
      'glassDisplacement': glassDisplacement,
      'glassBlur': glassBlur,
      'glassSaturation': glassSaturation,
      'glassChromaticAb': glassChromaticAb,
      'glassElasticity': glassElasticity,
      'glassCornerRadius': glassCornerRadius,
      'glassOverLight': glassOverLight,
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
    int? themeColorValue,
    int? uiStyle,
    int? glassRefractionMode,
    double? glassDisplacement,
    double? glassBlur,
    double? glassSaturation,
    double? glassChromaticAb,
    double? glassElasticity,
    double? glassCornerRadius,
    bool? glassOverLight,
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
      themeColorValue: themeColorValue ?? this.themeColorValue,
      uiStyle: uiStyle ?? this.uiStyle,
      glassRefractionMode: glassRefractionMode ?? this.glassRefractionMode,
      glassDisplacement: glassDisplacement ?? this.glassDisplacement,
      glassBlur: glassBlur ?? this.glassBlur,
      glassSaturation: glassSaturation ?? this.glassSaturation,
      glassChromaticAb: glassChromaticAb ?? this.glassChromaticAb,
      glassElasticity: glassElasticity ?? this.glassElasticity,
      glassCornerRadius: glassCornerRadius ?? this.glassCornerRadius,
      glassOverLight: glassOverLight ?? this.glassOverLight,
    );
  }
}
