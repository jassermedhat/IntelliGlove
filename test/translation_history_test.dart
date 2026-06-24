import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/components/translation_history_presenter.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/models/translation_record.dart';
import 'package:intelliglove/repositories/translation_repository.dart';
import 'package:intelliglove/screens/translation_history_screen.dart';
import 'package:intelliglove/services/translation_controller.dart';
import 'package:intelliglove/theme/theme_provider.dart';

void main() {
  test('history loads, deletes one record, and clears', () async {
    final repository = _Repository(records: [_record('1'), _record('2')]);
    final controller = TranslationController(repository: repository);

    await controller.loadHistory();
    expect(controller.historyStatus, LoadStatus.success);
    expect(controller.history, hasLength(2));

    expect(await controller.deleteRecord('1'), isTrue);
    expect(controller.history.single.id, '2');

    expect(await controller.clearHistory(), isTrue);
    expect(controller.historyStatus, LoadStatus.empty);
    expect(controller.history, isEmpty);
    controller.dispose();
  });

  test('history exposes empty and error states with retry', () async {
    final repository = _Repository();
    final controller = TranslationController(repository: repository);

    await controller.loadHistory();
    expect(controller.historyStatus, LoadStatus.empty);

    repository.shouldFail = true;
    await controller.retryHistory();
    expect(controller.historyStatus, LoadStatus.error);
    expect(controller.historyError, isNotEmpty);
    controller.dispose();
  });

  test('groups records into Today, Yesterday, and Earlier', () {
    final now = DateTime(2026, 6, 10, 12);
    final groups = groupTranslationHistory([
      _record('today', createdAt: now.subtract(const Duration(hours: 1))),
      _record('yesterday', createdAt: now.subtract(const Duration(days: 1))),
      _record('earlier', createdAt: now.subtract(const Duration(days: 3))),
    ], now: now);

    expect(groups.map((group) => group.label), [
      'Today',
      'Yesterday',
      'Earlier',
    ]);
  });

  testWidgets('Arabic history records render with RTL directionality', (
    tester,
  ) async {
    final controller = TranslationController(
      repository: _Repository(
        records: [_record('ar', text: 'شكرا', languageCode: 'ar-SA')],
      ),
    );

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: TranslationControllerScope(
          notifier: controller,
          child: const MaterialApp(home: TranslationHistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('شكرا'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('mock stream emits a canonical record and stops cleanly', () async {
    final repository = MockTranslationRepository(
      delay: const Duration(milliseconds: 5),
      initialHistory: const [],
    );
    await repository.startSession(languageCode: 'ar-SA');
    final record = await repository.translationStream().first;
    expect(record.languageCode, 'ar-SA');
    expect(record.isRtl, isTrue);
    await repository.stopSession();
  });
}

TranslationRecord _record(
  String id, {
  String text = 'Hello',
  String languageCode = 'en-US',
  DateTime? createdAt,
}) {
  return TranslationRecord(
    id: id,
    text: text,
    languageCode: languageCode,
    confidence: 0.95,
    createdAt: createdAt ?? DateTime(2026, 6, 10),
  );
}

class _Repository implements TranslationRepository {
  _Repository({List<TranslationRecord> records = const []})
    : records = List.of(records);

  final List<TranslationRecord> records;
  final stream = StreamController<TranslationRecord>.broadcast();
  bool shouldFail = false;

  @override
  String? get activeSessionId => null;

  @override
  int? get activeSessionNumber => null;

  void _checkFailure() {
    if (shouldFail) throw const TranslationRepositoryException();
  }

  @override
  Future<void> addRecord(TranslationRecord record) async {
    _checkFailure();
    records.insert(0, record);
  }

  @override
  Future<void> clearHistory() async {
    _checkFailure();
    records.clear();
  }

  @override
  Future<void> deleteRecord(String id) async {
    _checkFailure();
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<List<TranslationRecord>> loadHistory() async {
    _checkFailure();
    return List.of(records);
  }

  @override
  Future<void> startSession({required String languageCode}) async {
    _checkFailure();
  }

  @override
  Future<void> stopSession() async {}

  @override
  Stream<TranslationRecord> translationStream() => stream.stream;
}
