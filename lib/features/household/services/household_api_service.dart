import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/locality_model.dart';
import '../models/pickup_booking_model.dart';
import '../models/ewaste_model.dart';
import '../models/scrap_price_model.dart';

class ServiceUnavailableException implements Exception {
  ServiceUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// API Service for Household operations.
/// Interacts with FastAPI backend following strict security and truthful state rules.
class HouseholdApiService {
  HouseholdApiService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  /// Fetch verified Ballari localities reference points from backend.
  Future<List<LocalityModel>> fetchLocalities() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/pickups/localities/ballari',
      );
      final data = response.data;
      final list = data?['localities'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        return list
            .map((e) => LocalityModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Offline fallback to verified static Ballari localities.
    }
    return LocalityModel.verifiedBallariLocalities;
  }

  /// Create a new household pickup request.
  /// Calls real FastAPI POST /api/pickups.
  /// Household never enters estimated or actual weight.
  Future<PickupBookingResponse> createPickupRequest(
    PickupBookingRequest request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/pickups',
        data: request.toJson(),
      );

      final data = response.data;
      if (data == null) {
        throw StateError('Server returned empty response for pickup creation');
      }
      return PickupBookingResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw ServiceUnavailableException(
          'Pickup booking is not available yet. The collection service is still being connected.',
        );
      }
      if (e.response?.statusCode == 503) {
        throw ServiceUnavailableException(
          'Pickup booking is temporarily unavailable. Please try again later.',
        );
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw ServiceUnavailableException(
          'Your session has expired or is unauthorized. Please sign in again.',
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw ServiceUnavailableException(
          'Network connection error. Please check your internet connection.',
        );
      }
      throw ServiceUnavailableException(
        'Unable to submit pickup request right now. Please try again.',
      );
    } catch (e) {
      if (e is ServiceUnavailableException) rethrow;
      throw ServiceUnavailableException(
        'Unable to submit pickup request right now. Please try again.',
      );
    }
  }

  /// Fetch household-specific personal pickup history.
  /// STRICT SECURITY RULE: We do NOT query global /api/pickups/pending!
  /// A dedicated account-scoped endpoint is required.
  Future<List<PickupBookingResponse>> fetchPersonalPickups() async {
    // The account-scoped endpoint (e.g. /api/pickups/my) is pending backend integration.
    // Return empty list so UI presents truthful state.
    return const [];
  }

  /// Submit E-waste device image for assessment.
  /// Returns assessment result or throws ServiceUnavailableException if endpoint is unmerged.
  Future<EwasteAssessmentResult> assessEwaste(
    EwasteAssessmentRequest request,
  ) async {
    try {
      final formData = FormData.fromMap({
        'household_id': request.householdId,
        'image': MultipartFile.fromBytes(
          request.imageBytes,
          filename: request.imageFileName,
        ),
        if (request.deviceBrand != null && request.deviceBrand!.isNotEmpty)
          'device_brand': request.deviceBrand,
        if (request.deviceModel != null && request.deviceModel!.isNotEmpty)
          'device_model': request.deviceModel,
        if (request.deviceAgeYears != null)
          'device_age_years': request.deviceAgeYears,
        if (request.userReportedIssues != null &&
            request.userReportedIssues!.isNotEmpty)
          'user_reported_issues': request.userReportedIssues,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/e-waste/assessments',
        data: formData,
      );

      final data = response.data;
      if (data == null) {
        throw StateError('Empty assessment response from server');
      }
      return EwasteAssessmentResult.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 503) {
        throw ServiceUnavailableException(
          'E-Waste AI assessment endpoint is not connected on the server yet. '
          'The ML model integration is in progress.',
        );
      }
      rethrow;
    }
  }

  /// Fetch verified price board observations.
  /// Returns empty list if no server data source exists.
  Future<List<ScrapPriceItem>> fetchPriceBoard() async {
    // There is no /api/prices endpoint in the current backend.
    // Return empty list to prevent fabricating live prices.
    return const [];
  }
}
