import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intelliglove/services/backend_api_client.dart';

void main() {
  test('unwraps data and sends a Firebase bearer token', () async {
    late http.Request captured;
    final client = BackendApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      tokenProvider: ({forceRefresh = false}) async => 'firebase-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'data': {'name': 'Amina'}}), 200);
      }),
    );

    final data = await client.get('/me') as Map<String, dynamic>;
    expect(data['name'], 'Amina');
    expect(captured.headers['authorization'], 'Bearer firebase-token');
    client.close();
  });

  test('refreshes the Firebase token once after a 401', () async {
    var calls = 0;
    final refreshes = <bool>[];
    final client = BackendApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      tokenProvider: ({forceRefresh = false}) async {
        refreshes.add(forceRefresh);
        return forceRefresh ? 'fresh-token' : 'stale-token';
      },
      client: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'code': 'TOKEN_REFRESH_REQUIRED',
              'message': 'Refresh the token.',
            }),
            401,
          );
        }
        return http.Response(jsonEncode({'data': true}), 200);
      }),
    );

    expect(await client.get('/me'), isTrue);
    expect(refreshes, [false, true]);
    client.close();
  });

  test('maps disabled services to a typed API exception', () async {
    final client = BackendApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      tokenProvider: ({forceRefresh = false}) async => 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'SERVICE_DISABLED',
            'message': 'This feature is currently unavailable.',
          }),
          503,
        ),
      ),
    );

    await expectLater(
      client.get('/health-monitor'),
      throwsA(
        isA<BackendApiException>()
            .having((error) => error.isServiceDisabled, 'disabled', isTrue)
            .having(
              (error) => error.message,
              'message',
              'This feature is currently unavailable.',
            ),
      ),
    );
    client.close();
  });
}
