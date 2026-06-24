import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/glove_device.dart';
import 'package:intelliglove/repositories/glove_repository.dart';
import 'package:intelliglove/services/glove_state_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paired glove restores as disconnected and can be forgotten', () async {
    SharedPreferences.setMockInitialValues({
      'glove_device_id': 'stable-id',
      'glove_name': 'IntelliGlove Pro',
      'glove_battery': 81,
      'glove_signal': 4,
      'glove_firmware': 'v2.4.1',
      'glove_isConnected': true,
    });

    final provider = await GloveStateProvider.load(
      repository: MockGloveRepository(),
    );
    expect(provider.pairedDevice?.id, 'stable-id');
    expect(provider.connectionStatus, GloveConnectionStatus.disconnected);
    expect(provider.isConnected, isFalse);

    await provider.forgetDevice();
    expect(provider.pairedDevice, isNull);
  });
}
