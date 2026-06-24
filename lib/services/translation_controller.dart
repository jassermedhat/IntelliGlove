import 'dart:async';

import 'package:flutter/material.dart';

import '../models/load_status.dart';
import '../models/translation_record.dart';
import '../repositories/translation_repository.dart';
import '../repositories/backend_repositories.dart';
import '../services/backend_api_client.dart';
import 'tts_service.dart';

enum TranslationStatus { initial, loading, empty, error, offline, success }

class TranslationController extends ChangeNotifier {
  TranslationController({
    TranslationRepository? repository,
    TextToSpeechService? textToSpeech,
  }) : _repository = repository ?? BackendTranslationRepository(),
       _textToSpeech = textToSpeech ?? TextToSpeechService() {
    _textToSpeech.addListener(_handleSpeakingChanged);
  }

  final TranslationRepository _repository;
  final TextToSpeechService _textToSpeech;
  StreamSubscription<TranslationRecord>? _subscription;
  TranslationStatus _status = TranslationStatus.initial;
  String _text = '';
  String _lastTranslation = '';
  String? _errorMessage;
  List<TranslationRecord> _history = const [];
  LoadStatus _historyStatus = LoadStatus.initial;
  String? _historyError;
  double? _confidence;
  String _languageCode = 'en-US';
  bool _connected = false;
  bool _sessionActive = false;
  bool _listening = false;
  bool _autoSpeakActive = false;
  int _sessionToken = 0;
  int _translatedLettersCount = 0;

  TranslationStatus get status => _status;
  String get text => _text;
  String get lastTranslation => _lastTranslation;
  String? get errorMessage => _errorMessage;
  List<TranslationRecord> get history => List.unmodifiable(_history);
  LoadStatus get historyStatus => _historyStatus;
  String? get historyError => _historyError;
  double? get confidence => _confidence;
  String get languageCode => _languageCode;
  bool get isConnected => _connected;
  bool get isSessionActive => _sessionActive;
  bool get isListening => _listening;
  bool get isAutoSpeakActive => _autoSpeakActive;
  bool get isSpeaking => _textToSpeech.isSpeaking;
  bool get isLive => _sessionActive && _listening && _connected;
  String? get activeSessionId => _repository.activeSessionId;
  int? get activeSessionNumber => _repository.activeSessionNumber;
  int get translatedLettersCount => _translatedLettersCount;

  void setLanguage(String languageCode) {
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    notifyListeners();
  }

  Future<void> setConnected(bool connected) async {
    if (_connected == connected) return;
    _connected = connected;
    if (!connected) {
      await stop();
      _status = TranslationStatus.offline;
    } else {
      _status = _text.trim().isEmpty
          ? TranslationStatus.empty
          : TranslationStatus.success;
    }
    notifyListeners();
  }

  Future<bool> start() async {
    if (!_connected || _sessionActive) {
      if (!_connected) {
        _status = TranslationStatus.offline;
        _errorMessage = 'Connect an IntelliGlove before starting translation.';
        notifyListeners();
      }
      return false;
    }

    final token = ++_sessionToken;
    _status = TranslationStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.startSession(languageCode: _languageCode);
      if (!_isCurrent(token) || !_connected) return false;
      _sessionActive = true;
      _translatedLettersCount = 0;
      _listening = true;
      _status = _text.trim().isEmpty
          ? TranslationStatus.empty
          : TranslationStatus.success;
      await _subscription?.cancel();
      _subscription = _repository.translationStream().listen(
        (record) => _handleRecord(record, token),
        onError: (_) {
          if (!_isCurrent(token)) return;
          _listening = false;
          _errorMessage = 'Translation is temporarily unavailable.';
          _status = TranslationStatus.error;
          notifyListeners();
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      if (!_isCurrent(token)) return false;
      _sessionActive = false;
      _listening = false;
      _errorMessage = e is BackendApiException
          ? e.message
          : 'Could not start translation. Please try again.';
      _status = TranslationStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> stop() async {
    _sessionToken++;
    _sessionActive = false;
    _listening = false;
    _autoSpeakActive = false;
    await _subscription?.cancel();
    _subscription = null;
    await _textToSpeech.stop();
    try {
      await _repository.stopSession();
    } catch (_) {
      _errorMessage = 'Could not stop the translation session cleanly.';
    }
    _status = !_connected
        ? TranslationStatus.offline
        : (_text.trim().isEmpty
              ? TranslationStatus.empty
              : TranslationStatus.success);
    notifyListeners();
  }

  Future<void> leavePage() => stop();

  Future<void> loadHistory() async {
    _historyStatus = LoadStatus.loading;
    _historyError = null;
    notifyListeners();
    try {
      final history = await _repository.loadHistory();
      _history = List.unmodifiable(history);
      _historyStatus = history.isEmpty ? LoadStatus.empty : LoadStatus.success;
    } catch (_) {
      _history = const [];
      _historyStatus = LoadStatus.error;
      _historyError = 'Translation history could not be loaded.';
    }
    notifyListeners();
  }

  Future<bool> clearHistory() async {
    try {
      await _repository.clearHistory();
      _history = const [];
      _historyStatus = LoadStatus.empty;
      _historyError = null;
      notifyListeners();
      return true;
    } catch (_) {
      _historyError = 'Translation history could not be cleared.';
      _historyStatus = LoadStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecord(String id) async {
    try {
      await _repository.deleteRecord(id);
      _history = List.unmodifiable(_history.where((record) => record.id != id));
      _historyStatus = _history.isEmpty ? LoadStatus.empty : LoadStatus.success;
      _historyError = null;
      notifyListeners();
      return true;
    } catch (_) {
      _historyError = 'The translation could not be deleted.';
      notifyListeners();
      return false;
    }
  }

  Future<void> retryHistory() => loadHistory();

  /// Enters continuous-TTS mode: every new incoming translation is spoken once.
  /// Immediately speaks [_lastTranslation] if there is already text on screen.
  Future<void> startAutoSpeak() async {
    _autoSpeakActive = true;
    final text = _lastTranslation.trim();
    if (text.isNotEmpty) {
      unawaited(_textToSpeech.speak(text, _languageCode));
    }
    notifyListeners();
  }

  /// Exits continuous-TTS mode and silences any in-progress speech.
  Future<void> stopAutoSpeak() async {
    _autoSpeakActive = false;
    await _textToSpeech.stop();
    notifyListeners();
  }

  Future<bool> speak(String locale) async {
    final value = (_text.trim().isNotEmpty ? _text : _lastTranslation).trim();
    if (value.isEmpty) {
      _errorMessage = 'No translated text is available to speak.';
      notifyListeners();
      return false;
    }
    final spoken = await _textToSpeech.speak(value, locale);
    if (!spoken) {
      _errorMessage =
          'Text-to-speech is unavailable for the selected language.';
      notifyListeners();
    }
    return spoken;
  }

  Future<void> stopSpeaking() => _textToSpeech.stop();

  bool _isCurrent(int token) => token == _sessionToken;

  Future<void> _handleRecord(TranslationRecord record, int token) async {
    if (!_isCurrent(token) || !isLive) return;
    _text = record.text;
    if (record.text.trim().isNotEmpty) {
      _lastTranslation = record.text;
      if (_autoSpeakActive) {
        unawaited(_textToSpeech.speak(record.text, _languageCode));
      }
    }
    _confidence = record.confidence;
    _translatedLettersCount += record.text
        .replaceAll(RegExp(r'\s+'), '')
        .characters
        .length;
    _status = record.text.trim().isEmpty
        ? TranslationStatus.empty
        : TranslationStatus.success;
    try {
      await _repository.addRecord(record);
      if (!_isCurrent(token)) return;
      _history = List.unmodifiable([
        record,
        ..._history.where((item) => item.id != record.id),
      ]);
      _historyStatus = LoadStatus.success;
      _historyError = null;
    } catch (_) {
      if (!_isCurrent(token)) return;
      _historyError = 'The latest translation could not be saved.';
    }
    notifyListeners();
  }

  void _handleSpeakingChanged() => notifyListeners();

  @override
  void dispose() {
    _sessionToken++;
    _subscription?.cancel();
    _textToSpeech.removeListener(_handleSpeakingChanged);
    _textToSpeech.dispose();
    super.dispose();
  }
}

class TranslationControllerScope
    extends InheritedNotifier<TranslationController> {
  const TranslationControllerScope({
    super.key,
    required TranslationController super.notifier,
    required super.child,
  });

  static TranslationController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TranslationControllerScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'TranslationControllerScope.of() called without a '
        'TranslationControllerScope above the context.',
      );
    }
    return notifier;
  }
}
