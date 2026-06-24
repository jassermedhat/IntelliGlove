import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService extends ChangeNotifier {
  TextToSpeechService({FlutterTts? engine}) : _engine = engine {
    if (engine != null) _configureEngine(engine);
  }

  FlutterTts? _engine;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<bool> isLanguageAvailable(String locale) async {
    try {
      return await _getEngine().isLanguageAvailable(locale) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> speak(String text, String locale) async {
    final value = text.trim();
    if (value.isEmpty) {
      _resetSpeaking();
      return false;
    }

    try {
      await stop();
      if (!await isLanguageAvailable(locale)) return false;
      final engine = _getEngine();
      await engine.setLanguage(locale);
      await engine.setSpeechRate(0.5);
      await engine.setVolume(1.0);
      _setSpeaking(true);
      final result = await engine.speak(value);
      if (result != 1) {
        _resetSpeaking();
        return false;
      }
      return true;
    } catch (_) {
      _resetSpeaking();
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _engine?.stop();
    } finally {
      _resetSpeaking();
    }
  }

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    notifyListeners();
  }

  void _resetSpeaking() => _setSpeaking(false);

  FlutterTts _getEngine() {
    final existing = _engine;
    if (existing != null) return existing;
    final engine = FlutterTts();
    _engine = engine;
    _configureEngine(engine);
    return engine;
  }

  void _configureEngine(FlutterTts engine) {
    engine.setCompletionHandler(_resetSpeaking);
    engine.setCancelHandler(_resetSpeaking);
    engine.setErrorHandler((_) => _resetSpeaking());
  }

  @override
  void dispose() {
    _engine?.stop();
    super.dispose();
  }
}
