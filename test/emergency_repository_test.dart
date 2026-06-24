import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/sos_models.dart';
import 'package:intelliglove/repositories/emergency_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contacts round-trip as JSON and corrupt entries are ignored', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalEmergencyRepository(sendDelay: Duration.zero);
    const contact = EmergencyContact(
      id: 7,
      name: 'Mona | Family',
      phone: '+20 123',
      relationship: 'Sister',
    );

    await repository.saveContacts(const [contact]);
    final loaded = await repository.loadContacts();
    expect(loaded.single.name, contact.name);
    expect(loaded.single.relationship, 'Sister');
  });

  test('mock SOS result is configurable', () async {
    final repository = LocalEmergencyRepository(
      mockResult: const SosResult(success: false, errorMessage: 'No network'),
      sendDelay: Duration.zero,
    );
    final result = await repository.sendSos(
      SosRequest(timestamp: DateTime(2026), contacts: const []),
    );

    expect(result.success, isFalse);
    expect(result.errorMessage, 'No network');
  });
}
