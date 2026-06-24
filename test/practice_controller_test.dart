import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/models/practice_result.dart';
import 'package:intelliglove/models/practice_sign.dart';
import 'package:intelliglove/repositories/practice_repository.dart';
import 'package:intelliglove/services/practice_controller.dart';

void main() {
  test('loads ASL and ArSL content by selected language', () async {
    final controller = PracticeController(
      repository: MockPracticeRepository(delay: Duration.zero),
    );

    await controller.load('en-US');
    expect(controller.status, LoadStatus.success);
    expect(
      controller.signs.every((sign) => sign.languageCode == 'en-US'),
      true,
    );

    await controller.load('ar-SA');
    expect(
      controller.signs.every((sign) => sign.languageCode == 'ar-SA'),
      true,
    );
    expect(controller.signs.first.name, 'مرحبا');
    controller.dispose();
  });

  test('starts a session and adds its result to history', () async {
    final controller = PracticeController(
      repository: MockPracticeRepository(
        delay: Duration.zero,
        fixedAccuracy: 93,
      ),
    );
    await controller.load('en-US');
    final initialCount = controller.history.length;

    await controller.start(controller.signs.first);

    expect(controller.phase, PracticePhase.result);
    expect(controller.result?.accuracy, 93);
    expect(controller.history, hasLength(initialCount + 1));
    controller.dispose();
  });

  test('cancel prevents a late result from changing state', () async {
    final repository = _DelayedRepository();
    final controller = PracticeController(repository: repository);
    await controller.load('en-US');

    final pending = controller.start(controller.signs.first);
    controller.cancel();
    repository.complete();
    await pending;

    expect(controller.phase, PracticePhase.select);
    expect(controller.result, isNull);
    controller.dispose();
  });

  test('repository failure exposes retryable load error', () async {
    final repository = _Repository()..shouldFail = true;
    final controller = PracticeController(repository: repository);

    await controller.load('en-US');
    expect(controller.status, LoadStatus.error);
    expect(controller.error, isNotEmpty);

    repository.shouldFail = false;
    await controller.retryLoad();
    expect(controller.status, LoadStatus.success);
    controller.dispose();
  });

  test('disposing during a session does not apply a late result', () async {
    final repository = _DelayedRepository();
    final controller = PracticeController(repository: repository);
    await controller.load('en-US');

    final pending = controller.start(controller.signs.first);
    controller.dispose();
    repository.complete();
    await pending;
  });
}

class _Repository implements PracticeRepository {
  bool shouldFail = false;

  void _check() {
    if (shouldFail) throw const PracticeRepositoryException();
  }

  @override
  Future<PracticeResult> evaluateSession(PracticeSessionInput input) async {
    _check();
    return _result(input);
  }

  @override
  Future<List<PracticeResult>> loadHistory() async {
    _check();
    return const [];
  }

  @override
  Future<List<PracticeSign>> loadSigns(String languageCode) async {
    _check();
    return [
      PracticeSign(
        id: 'sign',
        name: 'Hello',
        emoji: 'wave',
        difficulty: 'Easy',
        languageCode: languageCode,
      ),
    ];
  }

  @override
  Future<PracticeStats> loadStats() async {
    _check();
    return const PracticeStats(
      totalPracticed: 0,
      averageAccuracy: 0,
      streak: 0,
    );
  }
}

class _DelayedRepository extends _Repository {
  final completer = Completer<PracticeResult>();

  void complete() {
    completer.complete(
      _result(
        const PracticeSessionInput(
          signId: 'sign',
          signName: 'Hello',
          languageCode: 'en-US',
        ),
      ),
    );
  }

  @override
  Future<PracticeResult> evaluateSession(PracticeSessionInput input) {
    return completer.future;
  }
}

PracticeResult _result(PracticeSessionInput input) {
  return PracticeResult(
    id: 'result',
    signId: input.signId,
    signName: input.signName,
    accuracy: 90,
    correct: true,
    suggestion: 'Good',
    languageCode: input.languageCode,
    createdAt: DateTime(2026),
  );
}
