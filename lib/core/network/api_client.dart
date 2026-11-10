import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Singleton Dio client for ScrapWise API calls.
/// Configured with base URL, timeouts and standard headers.
/// Actual endpoint calls are added by feature-layer services
/// once the FastAPI backend is available.
class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );
}

// ignore: avoid_annotating_with_dynamic
void debugPrint(dynamic msg) {
  // ignore: avoid_print
  print(msg);
}
