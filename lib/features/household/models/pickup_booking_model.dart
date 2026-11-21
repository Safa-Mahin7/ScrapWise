/// Represents a household pickup request submission and status.
class PickupBookingRequest {
  const PickupBookingRequest({
    required this.householdId,
    required this.localityId,
    required this.latitude,
    required this.longitude,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.materials,
    this.address,
    this.notes,
  });

  final String householdId;
  final String localityId;
  final double latitude;
  final double longitude;
  final DateTime preferredDate;
  final String preferredTimeSlot;
  final List<String> materials;
  final String? address;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'household_id': householdId,
        'locality_id': localityId,
        'latitude': latitude,
        'longitude': longitude,
        'preferred_date':
            '${preferredDate.year.toString().padLeft(4, '0')}-${preferredDate.month.toString().padLeft(2, '0')}-${preferredDate.day.toString().padLeft(2, '0')}',
        'preferred_time_slot': preferredTimeSlot,
        'materials': materials,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

class PickupBookingResponse {
  const PickupBookingResponse({
    required this.requestId,
    required this.householdId,
    required this.localityId,
    required this.latitude,
    required this.longitude,
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.materials,
    required this.status,
    this.notes,
    this.createdAt,
  });

  factory PickupBookingResponse.fromJson(Map<String, dynamic> json) {
    return PickupBookingResponse(
      requestId: json['request_id'] as String? ?? '',
      householdId: json['household_id'] as String? ?? '',
      localityId: json['locality_id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      preferredDate: json['preferred_date'] != null
          ? DateTime.tryParse(json['preferred_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      preferredTimeSlot: json['preferred_time_slot'] as String? ?? 'morning',
      materials: (json['materials'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String requestId;
  final String householdId;
  final String localityId;
  final double latitude;
  final double longitude;
  final DateTime preferredDate;
  final String preferredTimeSlot;
  final List<String> materials;
  final String status;
  final String? notes;
  final DateTime? createdAt;
}
