/// Represents an indicative market scrap price benchmark.
class ScrapPriceItem {
  const ScrapPriceItem({
    required this.materialId,
    required this.materialName,
    required this.indicativeRatePerKg,
    required this.locality,
    required this.priceSource,
    required this.lastUpdated,
    this.qualityGrade = 'Standard',
  });

  final String materialId;
  final String materialName;
  final double indicativeRatePerKg;
  final String locality;
  final String priceSource;
  final DateTime lastUpdated;
  final String qualityGrade;

  factory ScrapPriceItem.fromJson(Map<String, dynamic> json) {
    return ScrapPriceItem(
      materialId: json['material_type'] as String? ?? '',
      materialName: json['material_name'] as String? ?? json['material_type'] as String? ?? '',
      indicativeRatePerKg: (json['rate_per_kg'] as num?)?.toDouble() ?? 0.0,
      locality: json['locality_id'] as String? ?? 'Ballari Market',
      priceSource: json['price_source'] as String? ?? 'Verified Trader Observation',
      lastUpdated: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      qualityGrade: json['quality_grade'] as String? ?? 'Standard',
    );
  }
}
