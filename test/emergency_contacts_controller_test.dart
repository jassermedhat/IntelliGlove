import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/models/sos_models.dart';
import 'package:intelliglove/repositories/emergency_repository.dart';
import 'package:intelliglove/services/emergency_contacts_controller.dart';

void main() {
  test('contact drafts save and cancel independently', () async {
    final repository = _ContactsRepository();
    final controller = EmergencyContactsController(repository: repository);
    await controller.load();
    expect(controller.status, LoadStatus.success);

    controller.beginEditing();
    controller.addDraft();
    final added = controller.draftContacts.last;
    controller.updateDraft(
      added.id,
      name: 'Omar',
      phone: '+20 555',
      relationship: 'Brother',
    );
    expect(await controller.saveEdits(), isTrue);
    expect(controller.contacts.last.name, 'Omar');
    expect(repository.saved.length, 2);

    controller.beginEditing();
    controller.removeDraft(added.id);
    controller.cancelEditing();
    expect(controller.contacts.length, 2);
    controller.dispose();
  });

  test('invalid contact draft is not persisted', () async {
    final repository = _ContactsRepository();
    final controller = EmergencyContactsController(repository: repository);
    await controller.load();
    controller.beginEditing();
    controller.addDraft();

    expect(await controller.saveEdits(), isFalse);
    expect(controller.error, contains('name and phone'));
    expect(repository.saveCalls, 0);
    controller.dispose();
  });
}

class _ContactsRepository implements EmergencyRepository {
  List<EmergencyContact> saved = const [];
  int saveCalls = 0;

  @override
  Future<List<EmergencyContact>> loadContacts() async => const [
    EmergencyContact(id: 1, name: 'Mona', phone: '+20 123'),
  ];

  @override
  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    saveCalls++;
    saved = List.of(contacts);
  }

  @override
  Future<SosResult> sendSos(SosRequest request) async {
    return const SosResult(success: true);
  }
}
