/// Represents a verified locality in the operational city (Ballari).
class LocalityModel {
  const LocalityModel({
    required this.localityId,
    required this.localityName,
    required this.placeType,
    required this.latitude,
    required this.longitude,
  });

  factory LocalityModel.fromJson(Map<String, dynamic> json) {
    return LocalityModel(
      localityId: json['locality_id'] as String? ?? '',
      localityName: json['locality_name'] as String? ?? '',
      placeType: json['place_type'] as String? ?? 'suburb',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String localityId;
  final String localityName;
  final String placeType;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'locality_id': localityId,
        'locality_name': localityName,
        'place_type': placeType,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Verified Ballari locality reference points matching backend.
  static const List<LocalityModel> verifiedBallariLocalities = [
    LocalityModel(
      localityId: 'cowl_bazar',
      localityName: 'Cowl Bazar',
      placeType: 'suburb',
      latitude: 15.13649,
      longitude: 76.89829,
    ),
    LocalityModel(
      localityId: 'bandihatti',
      localityName: 'Bandihatti',
      placeType: 'suburb',
      latitude: 15.13281,
      longitude: 76.89022,
    ),
    LocalityModel(
      localityId: 'cantonment',
      localityName: 'Cantonment',
      placeType: 'suburb',
      latitude: 15.15718,
      longitude: 76.89061,
    ),
    LocalityModel(
      localityId: 'havambhavi',
      localityName: 'Havambhavi',
      placeType: 'suburb',
      latitude: 15.17144,
      longitude: 76.91217,
    ),
    LocalityModel(
      localityId: 'gandhinagara',
      localityName: 'Gandhi Nagar',
      placeType: 'suburb',
      latitude: 15.15795,
      longitude: 76.93757,
    ),
    LocalityModel(
      localityId: 'renuka_nagar',
      localityName: 'Renuka Nagar',
      placeType: 'suburb',
      latitude: 15.16184,
      longitude: 76.92708,
    ),
    LocalityModel(
      localityId: 'bandimot',
      localityName: 'Bandimot',
      placeType: 'suburb',
      latitude: 15.14005,
      longitude: 76.94168,
    ),
    LocalityModel(
      localityId: 'guggarahatti',
      localityName: 'Guggarahatti',
      placeType: 'nearby_village',
      latitude: 15.12215,
      longitude: 76.91029,
    ),
    LocalityModel(
      localityId: 'andralu',
      localityName: 'Andralu',
      placeType: 'nearby_village',
      latitude: 15.12344,
      longitude: 76.93233,
    ),
    LocalityModel(
      localityId: 'satyanarayana_pete',
      localityName: 'Satyanarayana Pete',
      placeType: 'locality',
      latitude: 15.14751,
      longitude: 76.95294,
    ),
  ];
}
