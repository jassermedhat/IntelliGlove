import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/models/smart_device.dart';
import 'package:intelliglove/models/translation_record.dart';
import 'package:intelliglove/repositories/smart_home_repository.dart';
import 'package:intelliglove/repositories/translation_repository.dart';
import 'package:intelliglove/services/smart_home_provider.dart';
import 'package:intelliglove/services/translation_controller.dart';
import 'package:intelliglove/services/tts_service.dart';

void main() {
  test(
    'translation controller requires an explicit connected session',
    () async {
      final repository = _TranslationRepository();
      final controller = TranslationController(repository: repository);

      await controller.setConnected(true);
      expect(controller.status, TranslationStatus.empty);
      expect(controller.isLive, isFalse);

      await controller.start();
      expect(controller.isLive, isTrue);
      expect(repository.startCount, 1);

      repository.add(
        TranslationRecord(
          id: 'result-1',
          text: 'Hello',
          languageCode: 'en-US',
          confidence: 0.98,
          createdAt: DateTime(2026),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.text, 'Hello');
      expect(controller.status, TranslationStatus.success);

      await controller.setConnected(false);
      expect(controller.status, TranslationStatus.offline);
      expect(controller.isLive, isFalse);
      expect(repository.stopCount, 1);
      controller.dispose();
    },
  );

  test(
    'translation controller speaks current and repeats last translated text',
    () async {
      final repository = _TranslationRepository();
      final tts = _TextToSpeechService();
      final controller = TranslationController(
        repository: repository,
        textToSpeech: tts,
      );
      await controller.setConnected(true);
      await controller.start();
      repository.add(
        TranslationRecord(
          id: 'spoken-1',
          text: 'Hello',
          languageCode: 'en-US',
          confidence: 0.9,
          createdAt: DateTime(2026),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await controller.speak('en-US'), isTrue);
      expect(tts.spoken, 'Hello');

      repository.add(
        TranslationRecord(
          id: 'spoken-2',
          text: '',
          languageCode: 'en-US',
          confidence: 0.8,
          createdAt: DateTime(2026),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await controller.speak('en-US'), isTrue);
      expect(tts.spoken, 'Hello');
      controller.dispose();
    },
  );

  test('smart home provider persists toggles', () async {
    final repository = _SmartHomeRepository();
    final provider = SmartHomeProvider(repository: repository);
    await provider.load();
    expect(provider.status, LoadStatus.success);

    await provider.toggleDevice(1);
    expect(provider.devices.single.isOn, isTrue);
    expect(repository.saved.single.isOn, isTrue);
  });
}

class _TranslationRepository implements TranslationRepository {
  final _controller = StreamController<TranslationRecord>.broadcast();
  final records = <TranslationRecord>[];
  int startCount = 0;
  int stopCount = 0;

  @override
  String? get activeSessionId => 'test-session';

  @override
  int? get activeSessionNumber => null;

  void add(TranslationRecord result) => _controller.add(result);

  @override
  Future<void> addRecord(TranslationRecord record) async {
    records.insert(0, record);
  }

  @override
  Future<void> clearHistory() async => records.clear();

  @override
  Future<void> deleteRecord(String id) async {
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<List<TranslationRecord>> loadHistory() async => List.of(records);

  @override
  Future<void> startSession({required String languageCode}) async {
    startCount++;
  }

  @override
  Future<void> stopSession() async {
    stopCount++;
  }

  @override
  Stream<TranslationRecord> translationStream() => _controller.stream;
}

class _TextToSpeechService extends TextToSpeechService {
  String? spoken;

  @override
  Future<bool> speak(String text, String locale) async {
    spoken = text;
    return true;
  }
}

class _SmartHomeRepository implements SmartHomeRepository {
  List<SmartDevice> saved = const [];

  @override
  Future<List<SmartDevice>> loadDevices() async => const [
    SmartDevice(
      id: 1,
      name: 'Lamp',
      iconKey: 'light',
      gesture: 'Wave',
      isOn: false,
    ),
  ];

  @override
  Future<void> saveDevices(List<SmartDevice> devices) async {
    saved = List.of(devices);
  }
}
