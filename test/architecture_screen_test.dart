import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/app_alert.dart';
import 'package:intelliglove/repositories/alerts_repository.dart';
import 'package:intelliglove/screens/device_updates_screen.dart';
import 'package:intelliglove/screens/home_screen.dart';
import 'package:intelliglove/services/alerts_controller.dart';
import 'package:intelliglove/theme/theme_provider.dart';

void main() {
  testWidgets('Home alert panel renders the latest controller alert', (
    tester,
  ) async {
    final alerts = AlertsController(
      repository: MockAlertsRepository(
        alerts: [
          AppAlert(
            id: 'latest',
            title: 'Latest',
            message: 'Controller-owned alert',
            type: AppAlertType.info,
            createdAt: DateTime(2026),
          ),
        ],
      ),
    );
    await alerts.load();
    final theme = ThemeProvider();

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: theme,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: HomeAlertsPanel(
                t: ThemeProviderScope.of(context).tokens,
                controller: alerts,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Controller-owned alert'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    alerts.dispose();
    theme.dispose();
  });

  testWidgets('Firmware badge visibly labels the simulation', (tester) async {
    final theme = ThemeProvider();
    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: theme,
        child: const MaterialApp(
          home: Scaffold(body: FirmwareSimulationBadge()),
        ),
      ),
    );

    expect(find.text('Simulation'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    theme.dispose();
  });
}
