import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sos_models.dart';

abstract class EmergencyRepository {
  Future<List<EmergencyContact>> loadContacts();
  Future<void> saveContacts(List<EmergencyContact> contacts);
  Future<SosResult> sendSos(SosRequest request);
}

class LocalEmergencyRepository implements EmergencyRepository {
  LocalEmergencyRepository({
    this.mockResult = const SosResult(success: true),
    this.sendDelay = const Duration(seconds: 2),
  });

  static const _contactsKey = 'sos_contacts_json';
  static const _lastSosKey = 'sos_last_local_request_json';
  final SosResult mockResult;
  final Duration sendDelay;

  @override
  Future<List<EmergencyContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_contactsKey);
    if (raw == null) return const [];

    final contacts = <EmergencyContact>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is! Map<String, dynamic>) continue;
        final contact = EmergencyContact.fromJson(decoded);
        if (contact != null) contacts.add(contact);
      } catch (_) {
        // Ignore corrupt entries while preserving the rest of the list.
      }
    }
    return contacts;
  }

  @override
  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = contacts.map((contact) => jsonEncode(contact.toJson()));
    final saved = await prefs.setStringList(_contactsKey, encoded.toList());
    if (!saved) throw StateError('Emergency contacts were not saved.');
  }

  @override
  Future<SosResult> sendSos(SosRequest request) async {
    await Future<void>.delayed(sendDelay);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSosKey, jsonEncode(request.toJson()));
    return mockResult;
  }
}
