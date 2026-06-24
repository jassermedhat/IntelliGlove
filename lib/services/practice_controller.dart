import 'package:flutter/material.dart';

import '../models/load_status.dart';
import '../models/practice_result.dart';
import '../models/practice_sign.dart';
import '../repositories/practice_repository.dart';
import '../repositories/backend_repositories.dart';

enum PracticePhase { select, practice, result }

class PracticeController extends ChangeNotifier {
  PracticeController({PracticeRepository? repository})
    : _repository = repository ?? BackendPracticeRepository();

  final PracticeRepository _repository;
  LoadStatus _status = LoadStatus.initial;
  PracticePhase _phase = PracticePhase.select;
  List<PracticeSign> _signs = const [];
  List<PracticeResult> _history = const [];
  PracticeStats _stats = const PracticeStats(
    totalPracticed: 0,
    averageAccuracy: 0,
    streak: 0,
  );
  PracticeSign? _selectedSign;
  PracticeResult? _result;
  String _languageCode = 'en-US';
  String? _error;
  int _sessionToken = 0;

  LoadStatus get status => _status;
  PracticePhase get phase => _phase;
  List<PracticeSign> get signs => List.unmodifiable(_signs);
  List<PracticeResult> get history => List.unmodifiable(_history);
  PracticeStats get stats => _stats;
  PracticeSign? get selectedSign => _selectedSign;
  PracticeResult? get result => _result;
  String get languageCode => _languageCode;
  String? get error => _error;
  bool get isPracticing => _phase == PracticePhase.practice;

  Future<void> load(String languageCode) async {
    final token = ++_sessionToken;
    _languageCode = languageCode;
    _status = LoadStatus.loading;
    _error = null;
    _phase = PracticePhase.select;
    _selectedSign = null;
    _result = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.loadSigns(languageCode),
        _repository.loadHistory(),
        _repository.loadStats(),
      ]);
      if (token != _sessionToken) return;
      _signs = results[0] as List<PracticeSign>;
      _history = results[1] as List<PracticeResult>;
      _stats = results[2] as PracticeStats;
      _status = _signs.isEmpty ? LoadStatus.empty : LoadStatus.success;
    } catch (_) {
      if (token != _sessionToken) return;
      _signs = const [];
      _status = LoadStatus.error;
      _error = 'Practice content could not be loaded.';
    }
    notifyListeners();
  }

  Future<void> start(PracticeSign sign) async {
    final token = ++_sessionToken;
    _selectedSign = sign;
    _result = null;
    _phase = PracticePhase.practice;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.evaluateSession(
        PracticeSessionInput(
          signId: sign.id,
          signName: sign.name,
          languageCode: _languageCode,
        ),
      );
      if (token != _sessionToken) return;
      _result = result;
      _history = List.unmodifiable([result, ..._history]);
      _phase = PracticePhase.result;
      notifyListeners();
    } catch (_) {
      if (token != _sessionToken) return;
      _phase = PracticePhase.select;
      _error = 'The practice session could not be evaluated.';
      notifyListeners();
    }
  }

  Future<void> retry() async {
    final sign = _selectedSign;
    if (sign != null) await start(sign);
  }

  void cancel() {
    _sessionToken++;
    _phase = PracticePhase.select;
    _selectedSign = null;
    _result = null;
    notifyListeners();
  }

  Future<void> retryLoad() => load(_languageCode);

  @override
  void dispose() {
    _sessionToken++;
    super.dispose();
  }
}
