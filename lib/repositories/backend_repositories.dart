import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../models/app_alert.dart';
import '../models/glove_device.dart';
import '../models/practice_result.dart';
import '../models/practice_sign.dart';
import '../models/smart_device.dart';
import '../models/translation_record.dart';
import '../services/backend_api_client.dart';
import '../services/development_testing_session.dart';
import 'alerts_repository.dart';
import 'analytics_repository.dart';
import 'firmware_repository.dart';
import 'glove_repository.dart';
import 'health_repository.dart';
import 'practice_repository.dart';
import 'smart_home_repository.dart';
import 'translation_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:web_socket_channel/web_socket_channel.dart';

Map<String, dynamic> _map(Object? value) => value! as Map<String, dynamic>;
List<dynamic> _list(Object? value) => value! as List<dynamic>;

// Derives the WebSocket base URL from the HTTP base URL.
// e.g. "http://10.0.2.2:8000/api/v1" → "ws://10.0.2.2:8000"
String _wsBase(String httpBase) {
  final uri = Uri.parse(httpBase);
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  return '$scheme://${uri.host}:${uri.port}';
}

class BackendGloveRepository implements GloveRepository {
  BackendGloveRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;

  final BackendApiClient _api;
  GloveDevice? _active;
  GloveConnectionStatus _connectionStatus = GloveConnectionStatus.connected;

  GloveConnectionStatus _status(Object? value) {
    final status = _map(value)['connectionStatus'] as String?;
    return switch (status) {
      'connected' => GloveConnectionStatus.connected,
      'connecting' || 'scanning' => GloveConnectionStatus.connecting,
      'error' => GloveConnectionStatus.unavailable,
      _ => GloveConnectionStatus.disconnected,
    };
  }

  GloveDevice _device(Object? value) {
    final map = _map(value);
    return GloveDevice(
      id: map['id']! as String,
      name: map['deviceName']! as String,
      hardwareAddress: map['hardwareId'] as String?,
      firmwareVersion: map['firmwareVersion'] as String?,
      batteryLevel: map['batteryLevel'] as int?,
      signalStrength: map['signalStrength'] as int?,
    );
  }

  @override
  Future<GloveDevice?> loadPairedDevice() async {
    final devices = _list(await _api.get('/devices'));
    if (devices.isEmpty) {
      _active = null;
      _connectionStatus = GloveConnectionStatus.disconnected;
      return null;
    }
    Object? selected = devices.first;
    for (final candidate in devices) {
      if (_status(candidate) == GloveConnectionStatus.connected) {
        selected = candidate;
        break;
      }
    }
    _active = _device(selected);
    _connectionStatus = _status(selected);
    return _active;
  }

  @override
  Future<List<GloveDevice>> scanDevices() async {
    // The backend returns registered devices. Physical BLE discovery remains a
    // typed hardware-adapter boundary until UUIDs/packet framing are supplied.
    return _list(await _api.get('/devices')).map(_device).toList();
  }

  @override
  Future<bool> connect(GloveDevice device) async {
    try {
      final data = await _api.patch(
        '/devices/${device.id}',
        body: {'connectionStatus': 'connected'},
      );
      _active = _device(data);
      _connectionStatus = GloveConnectionStatus.connected;
      return true;
    } on BackendApiException {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final active = _active;
    if (active == null) return;
    await _api.patch(
      '/devices/${active.id}',
      body: {'connectionStatus': 'disconnected'},
    );
    _active = null;
    _connectionStatus = GloveConnectionStatus.disconnected;
  }

  @override
  GloveConnectionStatus getStatus() => _connectionStatus;
}

class BackendTranslationRepository implements TranslationRepository {
  BackendTranslationRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;

  final BackendApiClient _api;
  String? _sessionId;
  int? _sessionNumber;
  WebSocketChannel? _channel;
  StreamController<TranslationRecord>? _streamController;

  // Issue 7 — reconnect state
  bool _reconnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 8;
  static const Duration _maxBackoff = Duration(seconds: 60);

  @override
  String? get activeSessionId => _sessionId;

  @override
  int? get activeSessionNumber => _sessionNumber;

  TranslationRecord _record(Object? value) {
    final map = _map(value);
    return TranslationRecord(
      id: map['entryId']! as String,
      text: map['translatedText']! as String,
      gestureLabel: map['gestureLabel'] as String?,
      languageCode: (map['languageCode'] as String?) ?? 'en-US',
      confidence: ((map['confidence'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.parse(map['timestamp']! as String),
    );
  }

  @override
  Future<void> startSession({required String languageCode}) async {
    Map<String, dynamic> data;
    try {
      data = _map(await _api.post('/sessions/start', body: {}));
    } on BackendApiException catch (e) {
      if (e.code == 'ACTIVE_SESSION_EXISTS') {
        // The backend has a live watcher for an existing session.
        // Try to stop it so the user gets a clean start.
        final details = e.details;
        final staleId = details is Map ? details['sessionId'] as String? : null;
        if (staleId != null) {
          try {
            await _api.post('/sessions/$staleId/stop', body: {'status': 'closed'});
          } catch (_) {}
          data = _map(await _api.post('/sessions/start', body: {}));
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
    _sessionId = data['sessionId']! as String;
    _sessionNumber = data['sessionNumber'] as int?;
    _reconnectAttempt = 0;
    await _connectWebSocket();
  }

  // Issue 7 — connects (or reconnects) the live-translation WebSocket.
  Future<void> _connectWebSocket() async {
    final sid = _sessionId;
    if (sid == null) return; // session already stopped

    final testingSession = await DevelopmentTestingSession.isActive();
    final uid = testingSession
        ? developmentTestingUserUid
        : fba.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Tear down any previous channel before opening a new one.
    final oldChannel = _channel;
    _channel = null;
    await oldChannel?.sink.close();

    _streamController ??= StreamController<TranslationRecord>.broadcast();

    final wsUrl = Uri.parse('${_wsBase(_api.baseUrl)}/ws/translation/$uid');
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen(
      (raw) {
        _reconnectAttempt = 0; // successful message resets backoff
        try {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = decoded['type'] as String?;

          if (type == 'ready') {
            _api.authenticationToken().then((token) {
              if (token != null) _channel?.sink.add(token);
            });
            return;
          }

          if (type == 'translation') {
            final entry = decoded['entry'] as Map<String, dynamic>?;
            if (entry != null) {
              final record = TranslationRecord(
                id: entry['entryId'] as String,
                text: entry['translatedText'] as String,
                languageCode: 'en-US',
                confidence: ((entry['confidence'] as num?) ?? 0).toDouble(),
                createdAt: DateTime.parse(entry['timestamp'] as String),
              );
              _streamController?.add(record);
            }
          }
          // ping/pong and other control messages are ignored.
        } catch (_) {
          // Malformed message — skip.
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
      cancelOnError: false,
    );
  }

  // Issue 7 — bounded exponential backoff reconnect.
  void _scheduleReconnect() {
    if (_sessionId == null || _reconnecting) return; // session stopped or already waiting
    if (_reconnectAttempt >= _maxReconnectAttempts) return; // give up after cap
    _reconnecting = true;
    final delay = Duration(
      milliseconds: math.min(
        _maxBackoff.inMilliseconds,
        (500 * math.pow(2, _reconnectAttempt)).round(),
      ),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnecting = false;
      _reconnectAttempt++;
      _connectWebSocket();
    });
  }

  @override
  Future<void> stopSession() async {
    final id = _sessionId;
    // Clear _sessionId first so _scheduleReconnect becomes a no-op.
    _sessionId = null;
    _sessionNumber = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = false;
    _reconnectAttempt = 0;
    await _channel?.sink.close();
    _channel = null;
    await _streamController?.close();
    _streamController = null;
    if (id == null) return;
    await _api.post('/sessions/$id/stop', body: {'status': 'closed'});
  }

  @override
  Stream<TranslationRecord> translationStream() {
    return _streamController?.stream ?? const Stream.empty();
  }

  @override
  Future<List<TranslationRecord>> loadHistory() async {
    return _list(await _api.get('/translations/history')).map(_record).toList();
  }

  @override
  Future<void> addRecord(TranslationRecord record) async {
    // Records are persisted by the backend ingestion watcher — no-op here.
  }

  @override
  Future<void> deleteRecord(String id) => _api.delete('/translations/$id');

  @override
  Future<void> clearHistory() => _api.delete('/translations');
}

class BackendHealthRepository implements HealthRepository {
  BackendHealthRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;

  @override
  Future<HealthVitals> getVitals({required bool isConnected}) async {
    if (!isConnected) return const HealthVitals.disconnected();
    final value = await _api.get('/health-monitor');
    if (value == null) return const HealthVitals.disconnected();
    final metrics = _map(_map(value)['metrics']);
    return HealthVitals(
      isDemo: metrics['isDemo'] == true,
      heartRate: metrics['heartRate'] as int?,
      bloodPressure: metrics['bloodPressure'] as String?,
      bloodOxygen: metrics['bloodOxygen'] as int?,
      respiratoryRate: metrics['respiratoryRate'] as int?,
      temperatureCelsius: (metrics['temperatureCelsius'] as num?)?.toDouble(),
      emotion: metrics['emotion'] as String?,
      activeEmotion: metrics['activeEmotion'] as int?,
    );
  }
}

class BackendAnalyticsRepository implements AnalyticsRepository {
  BackendAnalyticsRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;

  Future<AnalyticsData> _load(String range) async {
    final map = _map(await _api.get('/analytics', query: {'range': range}));
    return AnalyticsData(
      gestures: (map['gestures']! as List)
          .cast<num>()
          .map((e) => e.toInt())
          .toList(),
      labels: (map['labels']! as List).cast<String>(),
      accuracy: (map['accuracy']! as List)
          .cast<num>()
          .map((e) => e.toDouble())
          .toList(),
      sessionMinutes: (map['sessionMinutes']! as List)
          .cast<num>()
          .map((e) => e.toInt())
          .toList(),
      topGestures: (map['topGestures']! as List).map((value) {
        final item = _map(value);
        return GestureUsage(
          label: item['label']! as String,
          count: (item['count']! as num).toInt(),
          percentage: (item['percentage']! as num).toDouble(),
        );
      }).toList(),
    );
  }

  @override
  Future<AnalyticsData> loadDay() => _load('day');
  @override
  Future<AnalyticsData> loadWeek() => _load('week');
  @override
  Future<AnalyticsData> loadMonth() => _load('month');
}

class BackendAlertsRepository implements AlertsRepository {
  BackendAlertsRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;

  @override
  Future<List<AppAlert>> loadAlerts() async {
    return _list(await _api.get('/alerts')).map((value) {
      final map = _map(value);
      final name = (map['type'] as String?) ?? 'info';
      return AppAlert(
        id: map['id']! as String,
        title: map['title']! as String,
        message: map['message']! as String,
        type: AppAlertType.values.firstWhere(
          (value) => value.name == name,
          orElse: () => AppAlertType.info,
        ),
        createdAt: DateTime.parse(map['createdAt']! as String),
        isRead: map['isRead'] == true,
      );
    }).toList();
  }

  @override
  Future<void> markRead(String id) => _api.patch('/alerts/$id/read');
}

class BackendFirmwareRepository implements FirmwareRepository {
  BackendFirmwareRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;

  @override
  Future<FirmwareInfo> checkForUpdate() async {
    final devices = _list(await _api.get('/devices'));
    if (devices.isEmpty) {
      return const FirmwareInfo(currentVersion: 'Unknown');
    }
    final device = _map(devices.first);
    final data = _map(await _api.get('/firmware/devices/${device['id']}'));
    return FirmwareInfo(
      currentVersion: (data['currentVersion'] as String?) ?? 'Unknown',
      availableVersion: data['availableVersion'] as String?,
    );
  }

  @override
  Stream<double> installUpdate() async* {
    throw const FirmwareRepositoryException();
  }
}

class BackendSmartHomeRepository implements SmartHomeRepository {
  BackendSmartHomeRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;
  final Map<int, String> _backendIds = {};

  int _localId(String backendId) =>
      int.parse(backendId.replaceAll('-', '').substring(0, 8), radix: 16) &
      0x7fffffff;

  SmartDevice _device(Object? value) {
    final map = _map(value);
    final backendId = map['id']! as String;
    final state = _map(map['state']);
    final id = _localId(backendId);
    _backendIds[id] = backendId;
    return SmartDevice(
      id: id,
      backendId: backendId,
      name: map['deviceName']! as String,
      iconKey: (state['iconKey'] as String?) ?? (map['deviceType'] as String),
      gesture: (state['gesture'] as String?) ?? 'Unassigned',
      isOn: state['isOn'] == true,
    );
  }

  @override
  Future<List<SmartDevice>> loadDevices() async {
    return _list(await _api.get('/smart-house')).map(_device).toList();
  }

  @override
  Future<void> saveDevices(List<SmartDevice> devices) async {
    final currentIds = devices.map((device) => device.id).toSet();
    final removed = _backendIds.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in removed) {
      await _api.delete('/smart-house/${_backendIds.remove(id)}');
    }
    for (final device in devices) {
      final state = {
        'isOn': device.isOn,
        'gesture': device.gesture,
        'iconKey': device.iconKey,
      };
      final backendId = device.backendId ?? _backendIds[device.id];
      if (backendId == null) {
        final created = _map(
          await _api.post(
            '/smart-house',
            body: {
              'deviceName': device.name,
              'deviceType': device.iconKey,
              'state': state,
            },
          ),
        );
        _backendIds[device.id] = created['id']! as String;
      } else {
        await _api.patch('/smart-house/$backendId', body: {'state': state});
      }
    }
  }
}

class BackendPracticeRepository implements PracticeRepository {
  BackendPracticeRepository({BackendApiClient? api})
    : _api = api ?? BackendApiClient.instance;
  final BackendApiClient _api;
  String _language = 'en-US';

  Future<Map<String, dynamic>> _load() async => _map(
    await _api.get('/practice-mode', query: {'languageCode': _language}),
  );

  PracticeResult _result(Object? value) {
    final map = _map(value);
    final score = ((map['score'] as num?) ?? 0).round();
    return PracticeResult(
      id: map['id']! as String,
      signId: map['signId']! as String,
      signName: map['expectedText']! as String,
      accuracy: score,
      correct: map['correct'] == true,
      suggestion: score >= 85
          ? 'Great form!'
          : 'No model score is available for this attempt yet.',
      languageCode: _language,
      createdAt: DateTime.parse(map['createdAt']! as String),
    );
  }

  @override
  Future<List<PracticeSign>> loadSigns(String languageCode) async {
    _language = languageCode;
    final data = await _load();
    return (data['signs']! as List).map((value) {
      final map = _map(value);
      return PracticeSign(
        id: map['id']! as String,
        name: map['name']! as String,
        emoji: map['emoji']! as String,
        difficulty: map['difficulty']! as String,
        languageCode: map['languageCode']! as String,
      );
    }).toList();
  }

  @override
  Future<PracticeResult> evaluateSession(PracticeSessionInput input) async {
    final value = await _api.post(
      '/practice-mode/results',
      body: {'signId': input.signId, 'detectedText': input.signName},
    );
    return _result(value);
  }

  @override
  Future<List<PracticeResult>> loadHistory() async {
    final data = await _load();
    return (data['history']! as List).map(_result).toList();
  }

  @override
  Future<PracticeStats> loadStats() async {
    final stats = _map((await _load())['stats']);
    return PracticeStats(
      totalPracticed: stats['totalPracticed']! as int,
      averageAccuracy: stats['averageAccuracy']! as int,
      streak: stats['streak']! as int,
    );
  }
}
