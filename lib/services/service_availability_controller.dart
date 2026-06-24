import '../services/backend_api_client.dart';

class ServiceAvailabilityController {
  ServiceAvailabilityController({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;

  static final instance = ServiceAvailabilityController();
  final BackendApiClient _api;
  Map<String, bool> _services = const {};
  DateTime? _loadedAt;

  Future<void> refresh() async {
    final data = await _api.get('/service-status') as Map<String, dynamic>;
    _services = (data['services']! as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value == true),
    );
    _loadedAt = DateTime.now();
  }

  Future<bool> isEnabled(String key) async {
    final loadedAt = _loadedAt;
    if (loadedAt == null || DateTime.now().difference(loadedAt).inSeconds > 30) {
      await refresh();
    }
    return _services[key] ?? false;
  }
}
