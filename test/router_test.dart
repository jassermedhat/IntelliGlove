import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/app_routes.dart';

void main() {
  test('translation has one canonical services route', () {
    expect(AppRoutes.servicesTranslate, '/services/translate');
    expect(AppRoutes.servicesTranslateHistory, '/services/translate/history');
    expect(AppRoutes.profileDevices, '/profile/devices');
  });
}
