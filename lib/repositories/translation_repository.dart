import 'dart:async';

import '../models/translation_record.dart';

abstract class TranslationRepository {
  String? get activeSessionId => null;
  int? get activeSessionNumber => null;
  Future<void> startSession({required String languageCode});
  Future<void> stopSession();
  Stream<TranslationRecord> translationStream();
  Future<List<TranslationRecord>> loadHistory();
  Future<void> addRecord(TranslationRecord record);
  Future<void> deleteRecord(String id);
  Future<void> clearHistory();
}

class MockTranslationRepository implements TranslationRepository {
  MockTranslationRepository({
    this.emitSampleResults = true,
    this.shouldFail = false,
    this.delay = const Duration(seconds: 1),
    List<TranslationRecord>? initialHistory,
  }) : _history = List.of(initialHistory ?? _defaultHistory());

  final bool emitSampleResults;
  final bool shouldFail;
  final Duration delay;
  final List<TranslationRecord> _history;
  StreamController<TranslationRecord>? _streamController;
  Timer? _sampleTimer;
  int _sampleIndex = 0;
  String _languageCode = 'en-US';
  String? _sessionId;

  @override
  String? get activeSessionId => _sessionId;

  @override
  int? get activeSessionNumber => null;

  @override
  Future<void> startSession({required String languageCode}) async {
    if (shouldFail) throw const TranslationRepositoryException();
    _languageCode = languageCode;
    _sessionId = 'mock-session';
    _sampleTimer?.cancel();
    await _streamController?.close();
    _streamController = StreamController<TranslationRecord>.broadcast();
    if (emitSampleResults) {
      _scheduleSample();
    }
  }

  void _scheduleSample() {
    _sampleTimer = Timer(delay, () {
      final controller = _streamController;
      if (controller == null || controller.isClosed) return;
      final samples = _languageCode.toLowerCase().startsWith('ar')
          ? const [
              ('مرحبا', 'Greeting', '👋'),
              ('شكرا', 'Thanks', '🙏'),
              ('أحتاج مساعدة', 'Help', '✋'),
            ]
          : const [
              ('Hello', 'Greeting', '👋'),
              ('Thank you', 'Thanks', '🙏'),
              ('I need help', 'Help', '✋'),
            ];
      final sample = samples[_sampleIndex % samples.length];
      _sampleIndex++;
      final now = DateTime.now();
      controller.add(
        TranslationRecord(
          id: 'demo-${now.microsecondsSinceEpoch}',
          text: sample.$1,
          gestureLabel: sample.$2,
          gestureIcon: sample.$3,
          languageCode: _languageCode,
          confidence: 0.94,
          createdAt: now,
        ),
      );
      _scheduleSample();
    });
  }

  @override
  Future<void> stopSession() async {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    await _streamController?.close();
    _streamController = null;
    _sessionId = null;
  }

  @override
  Stream<TranslationRecord> translationStream() {
    return _streamController?.stream ?? const Stream.empty();
  }

  @override
  Future<List<TranslationRecord>> loadHistory() async {
    if (shouldFail) throw const TranslationRepositoryException();
    return List.unmodifiable(_history);
  }

  @override
  Future<void> addRecord(TranslationRecord record) async {
    if (shouldFail) throw const TranslationRepositoryException();
    _history.removeWhere((item) => item.id == record.id);
    _history.insert(0, record);
  }

  @override
  Future<void> deleteRecord(String id) async {
    if (shouldFail) throw const TranslationRepositoryException();
    _history.removeWhere((record) => record.id == id);
  }

  @override
  Future<void> clearHistory() async {
    if (shouldFail) throw const TranslationRepositoryException();
    _history.clear();
  }

  static List<TranslationRecord> _defaultHistory() {
    final now = DateTime.now();
    return [
      TranslationRecord(
        id: 'sample-1',
        text: 'Thank you',
        gestureLabel: 'Thanks',
        gestureIcon: '🙏',
        languageCode: 'en-US',
        confidence: 0.98,
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
      TranslationRecord(
        id: 'sample-2',
        text: 'I need help',
        gestureLabel: 'Help',
        gestureIcon: '✋',
        languageCode: 'en-US',
        confidence: 0.95,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      TranslationRecord(
        id: 'sample-3',
        text: 'شكرا',
        gestureLabel: 'Thanks',
        gestureIcon: '🙏',
        languageCode: 'ar-SA',
        confidence: 0.97,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

class TranslationRepositoryException implements Exception {
  const TranslationRepositoryException();
}
