import 'package:flutter/foundation.dart';

import '../models/load_status.dart';
import '../models/sos_models.dart';
import '../repositories/emergency_repository.dart';

class EmergencyContactsController extends ChangeNotifier {
  EmergencyContactsController({required EmergencyRepository repository})
    : _repository = repository;

  final EmergencyRepository _repository;
  LoadStatus _status = LoadStatus.initial;
  List<EmergencyContact> _contacts = const [];
  List<EmergencyContact>? _draftContacts;
  String? _error;

  LoadStatus get status => _status;
  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);
  List<EmergencyContact> get draftContacts =>
      List.unmodifiable(_draftContacts ?? _contacts);
  String? get error => _error;
  bool get isEditing => _draftContacts != null;

  Future<void> load() async {
    if (_status == LoadStatus.loading) return;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _contacts = await _repository.loadContacts();
      _status = _contacts.isEmpty ? LoadStatus.empty : LoadStatus.success;
    } catch (_) {
      _contacts = const [];
      _status = LoadStatus.error;
      _error = 'Emergency contacts could not be loaded.';
    }
    notifyListeners();
  }

  void beginEditing() {
    _draftContacts = List.of(_contacts);
    notifyListeners();
  }

  void addDraft() {
    final draft = _requireDraft();
    final nextId =
        draft.fold<int>(
          0,
          (highest, contact) => contact.id > highest ? contact.id : highest,
        ) +
        1;
    _draftContacts = [
      ...draft,
      EmergencyContact(id: nextId, name: '', phone: ''),
    ];
    notifyListeners();
  }

  void updateDraft(
    int id, {
    required String name,
    required String phone,
    String? relationship,
  }) {
    final draft = _requireDraft();
    _draftContacts = [
      for (final contact in draft)
        if (contact.id == id)
          contact.copyWith(
            name: name.trim(),
            phone: phone.trim(),
            relationship: relationship?.trim(),
          )
        else
          contact,
    ];
    notifyListeners();
  }

  void removeDraft(int id) {
    _draftContacts = _requireDraft()
        .where((contact) => contact.id != id)
        .toList();
    notifyListeners();
  }

  Future<bool> saveEdits() async {
    final draft = _requireDraft();
    if (draft.any(
      (contact) => contact.name.trim().isEmpty || contact.phone.trim().isEmpty,
    )) {
      _error = 'Each emergency contact needs a name and phone number.';
      notifyListeners();
      return false;
    }
    try {
      await _repository.saveContacts(draft);
      _contacts = List.unmodifiable(draft);
      _draftContacts = null;
      _status = _contacts.isEmpty ? LoadStatus.empty : LoadStatus.success;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Emergency contacts could not be saved.';
      notifyListeners();
      return false;
    }
  }

  void cancelEditing() {
    _draftContacts = null;
    _error = null;
    notifyListeners();
  }

  List<EmergencyContact> _requireDraft() {
    return _draftContacts ??= List.of(_contacts);
  }
}
