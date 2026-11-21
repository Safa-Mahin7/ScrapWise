/// Models for E-Waste device assessment and recommendations.
class EwasteAssessmentRequest {
  const EwasteAssessmentRequest({
    required this.householdId,
    required this.imageBytes,
    required this.imageFileName,
    this.deviceBrand,
    this.deviceModel,
    this.deviceAgeYears,
    this.userReportedIssues,
  });

  final String householdId;
  final List<int> imageBytes;
  final String imageFileName;
  final String? deviceBrand;
  final String? deviceModel;
  final int? deviceAgeYears;
  final String? userReportedIssues;
}

class RecoverableMaterialItem {
  const RecoverableMaterialItem({
    required this.material,
    this.estimatedQuantity,
    this.unit,
  });

  factory RecoverableMaterialItem.fromJson(Map<String, dynamic> json) {
    return RecoverableMaterialItem(
      material: json['material'] as String? ?? 'Unknown',
      estimatedQuantity: (json['estimated_quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? 'unknown',
    );
  }

  final String material;
  final double? estimatedQuantity;
  final String? unit;
}

enum RecommendedAction {
  repair,
  resale,
  recycle,
  manualInspection,
}

extension RecommendedActionExtension on RecommendedAction {
  static RecommendedAction fromString(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'repair' => RecommendedAction.repair,
      'resale' => RecommendedAction.resale,
      'recycle' => RecommendedAction.recycle,
      _ => RecommendedAction.manualInspection,
    };
  }

  String get label => switch (this) {
        RecommendedAction.repair => 'Repair & Reuse',
        RecommendedAction.resale => 'Refurbish & Resell',
        RecommendedAction.recycle => 'Responsible Recycling',
        RecommendedAction.manualInspection => 'Manual Inspection Required',
      };
}

class EwasteAssessmentResult {
  const EwasteAssessmentResult({
    required this.assessmentId,
    required this.householdId,
    required this.predictedDeviceType,
    required this.condition,
    required this.confidence,
    required this.recommendedAction,
    this.recoverableMaterials = const [],
    required this.assessmentStatus,
  });

  factory EwasteAssessmentResult.fromJson(Map<String, dynamic> json) {
    return EwasteAssessmentResult(
      assessmentId: json['assessment_id'] as String? ?? '',
      householdId: json['household_id'] as String? ?? '',
      predictedDeviceType: json['predicted_device_type'] as String? ?? 'Electronic Device',
      condition: json['condition'] as String? ?? 'Used',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      recommendedAction: RecommendedActionExtension.fromString(
        json['recommended_action'] as String?,
      ),
      recoverableMaterials: (json['recoverable_materials'] as List<dynamic>?)
              ?.map((item) => RecoverableMaterialItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      assessmentStatus: json['assessment_status'] as String? ?? 'completed',
    );
  }

  final String assessmentId;
  final String householdId;
  final String predictedDeviceType;
  final String condition;
  final double confidence;
  final RecommendedAction recommendedAction;
  final List<RecoverableMaterialItem> recoverableMaterials;
  final String assessmentStatus;
}
