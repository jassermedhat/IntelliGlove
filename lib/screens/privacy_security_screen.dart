// privacy_security_screen.dart
// Provides users with visibility into what data IntelliGlove accesses
// and how permissions are used.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/location_services.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/app_top_bar.dart';
import '../components/toast.dart';
import '../app_routes.dart';
import '../services/biometric_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key, this.locationPermissionService});

  final LocationPermissionService? locationPermissionService;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen>
    with WidgetsBindingObserver {
  late final LocationPermissionService _locationPermissionService;
  LocationPermissionState _locationStatus = LocationPermissionState.denied;
  bool _checkingPermission = true;
  bool _checkingBiometric = true;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _locationPermissionService =
        widget.locationPermissionService ?? DeviceLocationPermissionService();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
    _loadBiometric();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when user returns from system Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await _locationPermissionService.check();
    if (mounted) {
      setState(() {
        _locationStatus = status;
        _checkingPermission = false;
      });
    }
  }

  Future<void> _handleLocationAction() async {
    if (_locationStatus == LocationPermissionState.denied) {
      final result = await _locationPermissionService.request();
      if (mounted) setState(() => _locationStatus = result);
      return;
    }
    await _locationPermissionService.openSettings();
  }

  Future<void> _loadBiometric() async {
    if (Firebase.apps.isEmpty) {
      if (mounted) setState(() => _checkingBiometric = false);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final enabled = uid == null
        ? false
        : await BiometricService.instance.isEnabled(uid);
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _checkingBiometric = false;
      });
    }
  }

  Future<void> _toggleBiometric() async {
    if (Firebase.apps.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!_biometricEnabled && !await BiometricService.instance.authenticate()) {
      return;
    }
    final enabling = !_biometricEnabled;
    await BiometricService.instance.setEnabled(uid, enabling);
    if (mounted) setState(() => _biometricEnabled = enabling);
    if (enabling) {
      toast.success(
        title: 'Biometric lock enabled',
        description: 'Unlock the app with your fingerprint or face.',
      );
    } else {
      toast.info(title: 'Biometric lock disabled');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get _locationStatusLabel {
    if (_checkingPermission) return 'Checking...';
    if (_locationStatus == LocationPermissionState.granted) return 'Allowed';
    if (_locationStatus == LocationPermissionState.restricted) {
      return 'Restricted';
    }
    if (_locationStatus == LocationPermissionState.permanentlyDenied) {
      return 'Permanently Denied';
    }
    return 'Not Granted';
  }

  Color _locationStatusColor(AppColorTokens t) {
    if (_locationStatus == LocationPermissionState.granted) return t.success;
    if (_locationStatus == LocationPermissionState.restricted) return t.accent;
    if (_locationStatus == LocationPermissionState.permanentlyDenied) {
      return t.destructive;
    }
    return const Color(0xFFF59E0B); // amber
  }

  IconData get _locationStatusIcon {
    if (_locationStatus == LocationPermissionState.granted) {
      return Icons.check_circle_outline_rounded;
    }
    if (_locationStatus == LocationPermissionState.permanentlyDenied) {
      return Icons.block_rounded;
    }
    if (_locationStatus == LocationPermissionState.restricted) {
      return Icons.admin_panel_settings_outlined;
    }
    return Icons.warning_amber_rounded;
  }

  String get _locationActionLabel {
    if (_checkingPermission) return '';
    if (_locationStatus == LocationPermissionState.granted ||
        _locationStatus == LocationPermissionState.restricted) {
      return 'Manage in Settings';
    }
    if (_locationStatus == LocationPermissionState.permanentlyDenied) {
      return 'Open Settings';
    }
    return 'Grant Access';
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final locColor = _locationStatusColor(t);

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: 0,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 260),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 200),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: t.background.withValues(alpha: 0.75),
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppBackButton(fallbackRoute: AppRoutes.profile),
                      Text(
                        'Privacy & Security',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.foreground,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      AppLayout.bottomNavClearance(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SETTINGS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.accent,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Privacy & Security',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review how app data and permissions are used',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Location
                        _SectionLabel(t: t, label: 'LOCATION'),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          t: t,
                          isDark: isDark,
                          icon: Icons.location_on_outlined,
                          title: 'Location Access',
                          description:
                              'Used to prepare a location snapshot when you activate SOS. The app does not request background location permission.',
                          statusLabel: _locationStatusLabel,
                          statusColor: locColor,
                          statusIcon: _locationStatusIcon,
                          actionLabel: _locationActionLabel,
                          onManage: _checkingPermission
                              ? null
                              : _handleLocationAction,
                        ),
                        const SizedBox(height: 24),

                        // Account security
                        _SectionLabel(t: t, label: 'ACCOUNT SECURITY'),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          t: t,
                          isDark: isDark,
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometric Session Lock',
                          description:
                              'Uses device-local biometrics to unlock the Firebase session. Biometric data is never sent to the backend.',
                          statusLabel: _checkingBiometric
                              ? 'Checking...'
                              : _biometricEnabled
                              ? 'Enabled'
                              : 'Disabled',
                          statusColor: _biometricEnabled ? t.success : t.accent,
                          statusIcon: _biometricEnabled
                              ? Icons.check_circle_outline_rounded
                              : Icons.lock_outline_rounded,
                          actionLabel: _biometricEnabled ? 'Disable' : 'Enable',
                          onManage: _checkingBiometric
                              ? null
                              : _toggleBiometric,
                        ),
                        const SizedBox(height: 24),

                        // Bluetooth
                        _SectionLabel(t: t, label: 'BLUETOOTH'),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          t: t,
                          isDark: isDark,
                          icon: Icons.bluetooth_rounded,
                          title: 'Bluetooth & BLE',
                          description:
                              'Used to communicate with a paired IntelliGlove. Future connected services may have separate data practices.',
                          statusLabel: 'Local device only',
                          statusColor: t.accent,
                          statusIcon: Icons.check_circle_outline_rounded,
                          actionLabel: '',
                          onManage: null,
                        ),
                        const SizedBox(height: 24),

                        // Data storage
                        _SectionLabel(t: t, label: 'DATA STORAGE'),
                        const SizedBox(height: 12),
                        _PermissionCard(
                          t: t,
                          isDark: isDark,
                          icon: Icons.storage_rounded,
                          title: 'Emergency Contacts',
                          description:
                              'Emergency contacts and SOS records stay on this device in SharedPreferences and are never uploaded.',
                          statusLabel: 'Local only',
                          statusColor: t.success,
                          statusIcon: Icons.check_circle_outline_rounded,
                          actionLabel: '',
                          onManage: null,
                        ),
                        const SizedBox(height: 10),
                        _PermissionCard(
                          t: t,
                          isDark: isDark,
                          icon: Icons.translate_rounded,
                          title: 'Translation History',
                          description:
                              'Translation history is stored in PostgreSQL and is restricted to your Firebase-authenticated account.',
                          statusLabel: 'Account protected',
                          statusColor: t.success,
                          statusIcon: Icons.check_circle_outline_rounded,
                          actionLabel: '',
                          onManage: null,
                        ),
                        const SizedBox(height: 24),

                        // Info banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: t.card,
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                t.accent.withValues(
                                  alpha: isDark ? 0.08 : 0.04,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: t.accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Your Privacy, Our Priority',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: t.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Account and feature data is stored in PostgreSQL under your Firebase identity. Onboarding, preferences, biometrics, emergency contacts, and SOS records remain device-local.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: t.mutedForeground,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Permission card
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final IconData icon;
  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String actionLabel;
  final VoidCallback? onManage;

  const _PermissionCard({
    required this.t,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.actionLabel,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Icon(icon, size: 20, color: t.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: t.mutedForeground,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                // Status row
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onManage != null && actionLabel.isNotEmpty) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: onManage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final AppColorTokens t;
  final String label;
  const _SectionLabel({required this.t, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 20,
        height: 4,
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: t.mutedForeground,
          letterSpacing: 1.8,
        ),
      ),
    ],
  );
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
