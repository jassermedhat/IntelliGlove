import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/biometric_service.dart';

class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  bool _checking = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (Firebase.apps.isEmpty) {
      if (mounted) setState(() { _checking = false; _unlocked = true; });
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !await BiometricService.instance.isEnabled(user.uid)) {
      if (mounted) setState(() { _checking = false; _unlocked = true; });
      return;
    }
    final unlocked = await BiometricService.instance.authenticate();
    if (mounted) setState(() { _checking = false; _unlocked = unlocked; });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return ColoredBox(
      color: const Color(0xFF07121F),
      child: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : FilledButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock IntelliGlove'),
              ),
      ),
    );
  }
}
