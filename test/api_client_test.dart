import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/network/api_client.dart';

void main() {
  test('API client sends auth data without printing network diagnostics',
      () async {
    final dio = ApiClient.instance.dio;
    final output = <String>[];
    const authorization = 'Bearer synthetic-access-token';
    const payload = {'refresh_token': 'synthetic-refresh-token'};
    final stub = InterceptorsWrapper(
      onRequest: (options, handler) {
        expect(options.headers['Authorization'], authorization);
        expect(options.data, payload);
        final response = Response<Map<String, String>>(
          requestOptions: options,
          statusCode: options.path == '/success' ? 200 : 401,
          data: payload,
        );
        if (response.statusCode == 200) {
          handler.resolve(response, true);
          return;
        }
        handler.reject(
          DioException.badResponse(
            statusCode: 401,
            requestOptions: options,
            response: response,
          ),
          true,
        );
      },
    );
    dio.interceptors.add(stub);
    addTearDown(() => dio.interceptors.remove(stub));

    await runZoned(
      () async {
        final options = Options(headers: {'Authorization': authorization});
        final response =
            await dio.post('/success', options: options, data: payload);
        expect(response.data, payload);
        await expectLater(
          dio.post('/failure', options: options, data: payload),
          throwsA(isA<DioException>()),
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => output.add(line),
      ),
    );

    expect(output, isEmpty);
  });
}
