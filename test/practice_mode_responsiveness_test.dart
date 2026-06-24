import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/screens/practice_mode_screen.dart';
import 'package:intelliglove/services/glove_state_provider.dart';
import 'package:intelliglove/services/practice_controller.dart';
import 'package:intelliglove/services/preferences_provider.dart';
import 'package:intelliglove/repositories/practice_repository.dart';
import 'package:intelliglove/theme/theme_provider.dart';

// Phase 2 regression: the "Choose a sign" grid previously used a hand-computed
// childAspectRatio that under-estimated tile height and overflowed each cell.
// These tests pump the real screen (with a mock-backed controller) at the
// requested breakpoints and assert no render exception (overflow) occurs.
void main() {
  Future<void> pumpPractice(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PracticeController(
      repository: MockPracticeRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: GloveStateScope(
          notifier: GloveStateProvider(),
          child: PreferencesScope(
            notifier: PreferencesProvider(),
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: MaterialApp(
                home: PracticeModeScreen(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Phone, large phone, tablet, small-desktop, desktop widths.
  for (final width in <double>[320, 375, 768, 1024, 1440]) {
    testWidgets('Practice Mode has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await pumpPractice(tester, size: Size(width, 800));
      // The sign grid must be present (content loaded, not the error state)…
      expect(find.text('Hello'), findsWidgets);
      // …and nothing may have overflowed.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Practice Mode sign grid survives 2x text scale at 320px', (
    tester,
  ) async {
    await pumpPractice(tester, size: const Size(320, 800), textScale: 2.0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
