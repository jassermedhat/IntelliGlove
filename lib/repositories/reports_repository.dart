import '../services/backend_api_client.dart';

abstract class ReportsRepository {
  Future<void> submit({
    required String type,
    required String message,
    String? topic,
  });
}

class BackendReportsRepository implements ReportsRepository {
  BackendReportsRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;

  @override
  Future<void> submit({
    required String type,
    required String message,
    String? topic,
  }) async {
    await _api.post(
      '/reports',
      body: {
        'type': type,
        'message': topic == null ? message : '[$topic]\n$message',
        'appVersion': '1.0.0',
      },
    );
  }
}
