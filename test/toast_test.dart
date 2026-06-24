import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/components/toast.dart';
import 'package:intelliglove/theme/theme_provider.dart';

void main() {
  tearDown(toast.dismissAll);

  testWidgets('new toast replaces the current toast and action fires', (
    tester,
  ) async {
    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SizedBox(height: 72),
            body: Stack(children: [AppToaster()]),
          ),
        ),
      ),
    );

    toast.success(description: 'Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    var actionCalled = false;
    toast.action(
      message: 'No glove connected',
      actionLabel: 'Pair Device',
      onAction: () => actionCalled = true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('No glove connected'), findsOneWidget);

    await tester.tap(find.text('Pair Device'));
    expect(actionCalled, isTrue);
  });

  testWidgets('stale timer cannot dismiss a replacement toast', (tester) async {
    await tester.pumpWidget(_toastApp());
    toast.show(description: 'Old', duration: const Duration(milliseconds: 100));
    await tester.pump();
    toast.show(description: 'New', duration: const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Old'), findsNothing);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('respects maximum visible count and auto dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(_toastApp(maxVisible: 2));
    toast.show(description: 'One', duration: const Duration(seconds: 2));
    toast.show(description: 'Two', duration: const Duration(milliseconds: 50));
    toast.show(description: 'Three', duration: const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Two'), findsNothing);
    expect(find.text('Three'), findsOneWidget);
  });

  testWidgets('bottom offset adapts to navigation, inset, and text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _toastApp(
        hasBottomNavigation: false,
        mediaQueryData: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 40),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );
    toast.info(description: 'Adaptive');
    await tester.pump();

    final positioned = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(positioned.bottom, greaterThanOrEqualTo(52));
    expect(positioned.bottom, lessThan(88));
  });
}

Widget _toastApp({
  int maxVisible = 1,
  bool hasBottomNavigation = true,
  MediaQueryData mediaQueryData = const MediaQueryData(),
}) => ThemeProviderScope(
  notifier: ThemeProvider(),
  child: MaterialApp(
    home: MediaQuery(
      data: mediaQueryData,
      child: Scaffold(
        body: Stack(
          children: [
            AppToaster(
              maxVisible: maxVisible,
              hasBottomNavigation: hasBottomNavigation,
            ),
          ],
        ),
      ),
    ),
  ),
);
