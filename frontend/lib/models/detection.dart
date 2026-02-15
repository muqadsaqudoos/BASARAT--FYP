/// Single detection from backend: label and confidence score.
class DetectionModel {
  final String label;
  final double score;

  DetectionModel({required this.label, required this.score});

  factory DetectionModel.fromJson(Map<String, dynamic> json) {
    return DetectionModel(
      label: (json['label'] as String?) ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Response from POST /detect.
class DetectResponseModel {
  final List<DetectionModel> detections;
  final int? imageWidth;
  final int? imageHeight;

  DetectResponseModel({
    required this.detections,
    this.imageWidth,
    this.imageHeight,
  });

  factory DetectResponseModel.fromJson(Map<String, dynamic> json) {
    final list = json['detections'] as List<dynamic>? ?? [];
    return DetectResponseModel(
      detections: list
          .map((e) => DetectionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      imageWidth: json['imageWidth'] as int?,
      imageHeight: json['imageHeight'] as int?,
    );
  }
}
