class ModelStatus {
  final String name;
  final String description;
  final bool isAvailable;
  final String? size;
  final String? version;

  const ModelStatus({
    required this.name,
    required this.description,
    required this.isAvailable,
    this.size,
    this.version,
  });
}

class ModelsAvailability {
  final bool stemSeparationAvailable;
  final bool chordDetectionAvailable;
  final bool beatDetectionAvailable;
  final List<ModelStatus> models;

  const ModelsAvailability({
    required this.stemSeparationAvailable,
    required this.chordDetectionAvailable,
    required this.beatDetectionAvailable,
    required this.models,
  });

  bool get allModelsAvailable =>
      stemSeparationAvailable && chordDetectionAvailable && beatDetectionAvailable;

  int get availableCount =>
      (stemSeparationAvailable ? 1 : 0) +
      (chordDetectionAvailable ? 1 : 0) +
      (beatDetectionAvailable ? 1 : 0);
}
