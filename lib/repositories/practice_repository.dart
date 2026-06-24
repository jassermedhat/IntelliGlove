import 'dart:math';

import '../models/practice_result.dart';
import '../models/practice_sign.dart';

abstract class PracticeRepository {
  Future<List<PracticeSign>> loadSigns(String languageCode);
  Future<PracticeResult> evaluateSession(PracticeSessionInput input);
  Future<List<PracticeResult>> loadHistory();
  Future<PracticeStats> loadStats();
}

class MockPracticeRepository implements PracticeRepository {
  MockPracticeRepository({
    this.delay = const Duration(seconds: 3),
    this.shouldFail = false,
    int? fixedAccuracy,
  }) : _fixedAccuracy = fixedAccuracy;

  final Duration delay;
  final bool shouldFail;
  final int? _fixedAccuracy;

  @override
  Future<List<PracticeSign>> loadSigns(String languageCode) async {
    _checkFailure();
    return languageCode.toLowerCase().startsWith('ar')
        ? _arabicSigns
        : _aslSigns;
  }

  @override
  Future<PracticeResult> evaluateSession(PracticeSessionInput input) async {
    _checkFailure();
    await Future<void>.delayed(delay);
    _checkFailure();
    final accuracy = _fixedAccuracy ?? 75 + Random().nextInt(25);
    final correct = accuracy >= 85;
    return PracticeResult(
      id: 'practice-${DateTime.now().microsecondsSinceEpoch}',
      signId: input.signId,
      signName: input.signName,
      accuracy: accuracy,
      correct: correct,
      suggestion: correct
          ? 'Great form! Your gesture was recognized accurately.'
          : 'Adjust finger position slightly and hold the gesture steadier.',
      languageCode: input.languageCode,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<PracticeResult>> loadHistory() async {
    _checkFailure();
    final now = DateTime.now();
    return [
      PracticeResult(
        id: 'history-1',
        signId: 'asl-hello',
        signName: 'Hello',
        accuracy: 96,
        correct: true,
        suggestion: 'Great form!',
        languageCode: 'en-US',
        createdAt: now,
      ),
      PracticeResult(
        id: 'history-2',
        signId: 'asl-thanks',
        signName: 'Thank You',
        accuracy: 88,
        correct: true,
        suggestion: 'Great form!',
        languageCode: 'en-US',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Future<PracticeStats> loadStats() async {
    _checkFailure();
    return const PracticeStats(
      totalPracticed: 47,
      averageAccuracy: 91,
      streak: 5,
    );
  }

  void _checkFailure() {
    if (shouldFail) throw const PracticeRepositoryException();
  }
}

class PracticeRepositoryException implements Exception {
  const PracticeRepositoryException();
}

const _aslSigns = [
  PracticeSign(
    id: 'asl-hello',
    name: 'Hello',
    emoji: '👋',
    difficulty: 'Easy',
    languageCode: 'en-US',
  ),
  PracticeSign(
    id: 'asl-thanks',
    name: 'Thank You',
    emoji: '🙏',
    difficulty: 'Easy',
    languageCode: 'en-US',
  ),
  PracticeSign(
    id: 'asl-help',
    name: 'Help',
    emoji: '✋',
    difficulty: 'Easy',
    languageCode: 'en-US',
  ),
  PracticeSign(
    id: 'asl-love',
    name: 'I Love You',
    emoji: '🤟',
    difficulty: 'Medium',
    languageCode: 'en-US',
  ),
];

const _arabicSigns = [
  PracticeSign(
    id: 'arsl-hello',
    name: 'مرحبا',
    emoji: '👋',
    difficulty: 'Easy',
    languageCode: 'ar-SA',
  ),
  PracticeSign(
    id: 'arsl-thanks',
    name: 'شكرا',
    emoji: '🙏',
    difficulty: 'Easy',
    languageCode: 'ar-SA',
  ),
  PracticeSign(
    id: 'arsl-help',
    name: 'مساعدة',
    emoji: '✋',
    difficulty: 'Medium',
    languageCode: 'ar-SA',
  ),
  PracticeSign(
    id: 'arsl-stop',
    name: 'توقف',
    emoji: '✋',
    difficulty: 'Medium',
    languageCode: 'ar-SA',
  ),
];
