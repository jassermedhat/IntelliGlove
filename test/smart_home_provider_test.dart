import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/smart_device.dart';
import 'package:intelliglove/repositories/smart_home_repository.dart';
import 'package:intelliglove/services/smart_home_provider.dart';

void main() {
  const lamp = SmartDevice(
    id: 1,
    name: 'Lamp',
    iconKey: 'light',
    gesture: 'Wave',
    isOn: false,
  );

  test('add, toggle, edit, gesture, and remove persist successfully', () async {
    final repository = _Repository(initial: [lamp]);
    final provider = SmartHomeProvider(repository: repository);
    await provider.load();

    expect(
      await provider.addDevice(
        const SmartDevice(
          id: 2,
          name: 'TV',
          iconKey: 'tv',
          gesture: 'Point',
          isOn: false,
        ),
      ),
      isTrue,
    );
    expect(await provider.toggleDevice(1), isTrue);
    expect(await provider.editDevice(lamp.copyWith(name: 'Desk Lamp')), isTrue);
    expect(await provider.updateGesture(1, 'Pinch'), isTrue);
    expect(await provider.removeDevice(2), isTrue);
    expect(repository.saved.single.gesture, 'Pinch');
    provider.dispose();
  });

  test('every failed mutation rolls back and reports failure', () async {
    final repository = _Repository(initial: [lamp], shouldFail: true);
    final provider = SmartHomeProvider(repository: repository);
    await provider.load();

    expect(await provider.toggleDevice(1), isFalse);
    expect(provider.devices.single.isOn, isFalse);
    expect(await provider.editDevice(lamp.copyWith(name: 'Changed')), isFalse);
    expect(provider.devices.single.name, 'Lamp');
    expect(await provider.updateGesture(1, 'Pinch'), isFalse);
    expect(provider.devices.single.gesture, 'Wave');
    expect(await provider.removeDevice(1), isFalse);
    expect(provider.devices, hasLength(1));
    expect(await provider.addDevice(lamp.copyWith(id: 2)), isFalse);
    expect(provider.devices, hasLength(1));
    expect(provider.errorMessage, isNotEmpty);
    provider.dispose();
  });

  test('saving state prevents overlapping mutations', () async {
    final repository = _Repository(initial: [lamp], delayed: true);
    final provider = SmartHomeProvider(repository: repository);
    await provider.load();

    final pending = provider.toggleDevice(1);
    expect(provider.isSaving, isTrue);
    expect(await provider.removeDevice(1), isFalse);
    repository.completeSave();
    expect(await pending, isTrue);
    expect(provider.isSaving, isFalse);
    provider.dispose();
  });
}

class _Repository implements SmartHomeRepository {
  _Repository({
    required List<SmartDevice> initial,
    this.shouldFail = false,
    this.delayed = false,
  }) : initial = List.of(initial);

  final List<SmartDevice> initial;
  final bool shouldFail;
  final bool delayed;
  final Completer<void> _saveCompleter = Completer();
  List<SmartDevice> saved = const [];

  void completeSave() {
    if (!_saveCompleter.isCompleted) _saveCompleter.complete();
  }

  @override
  Future<List<SmartDevice>> loadDevices() async => List.of(initial);

  @override
  Future<void> saveDevices(List<SmartDevice> devices) async {
    if (delayed) await _saveCompleter.future;
    if (shouldFail) throw StateError('save failed');
    saved = List.of(devices);
  }
}
