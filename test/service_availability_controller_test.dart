import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intelliglove/services/backend_api_client.dart';
import 'package:intelliglove/services/service_availability_controller.dart';

void main() {
  test('service availability reflects the backend toggle map', () async {
    final api = BackendApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      tokenProvider: ({forceRefresh = false}) async => 'firebase-token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'systemStatus': 'on',
              'services': {'translation': false, 'analytics': true},
            },
          }),
          200,
        ),
      ),
    );
    final controller = ServiceAvailabilityController(api: api);

    expect(await controller.isEnabled('translation'), isFalse);
    expect(await controller.isEnabled('analytics'), isTrue);
    expect(await controller.isEnabled('missing'), isFalse);
    api.close();
  });
}
