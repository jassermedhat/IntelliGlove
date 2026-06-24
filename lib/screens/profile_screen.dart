// profile_screen.dart

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/theme_toggle_switch.dart';
import '../services/auth_provider.dart';
import '../services/preferences_provider.dart';
import '../app_routes.dart';
import '../components/toast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const _quickLinks = [
    (
      icon: Icons.palette_outlined,
      label: 'Appearance',
      desc: 'Theme & colors',
      path: AppRoutes.profileAppearance,
    ),
    (
      icon: Icons.shield_outlined,
      label: 'Privacy & Security',
      desc: 'Data & permissions',
      path: AppRoutes.profilePrivacySecurity,
    ),
    (
      icon: Icons.bluetooth_rounded,
      label: 'Devices',
      desc: 'Manage paired glove and connection',
      path: AppRoutes.profileDevices,
    ),
    (
      icon: Icons.help_outline_rounded,
      label: 'Help & Feedback',
      desc: 'Support center',
      path: AppRoutes.profileHelpFeedback,
    ),
    (
      icon: Icons.quiz_outlined,
      label: 'FAQ',
      desc: 'Frequently asked questions',
      path: AppRoutes.profileFaq,
    ),
  ];

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _savePreference(Future<bool> Function() save) async {
    if (await save() || !mounted) return;
    toast.error(
      title: 'Preference not saved',
      description: 'Your previous setting was restored.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final provider = ThemeProviderScope.of(context);
    final preferences = PreferencesScope.of(context);

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: 0,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 280),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 220),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [t.primary, t.primaryGlow],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'IntelliGlove',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.foreground,
                        ),
                      ),
                      const Spacer(),
                      ThemeToggleSwitch(
                        isDark: provider.isDark,
                        onTap: provider.toggleTheme,
                      ),
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
                        // Header
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
                              'PROFILE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.accent,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Profile card
                        _ProfileCard(t: t, isDark: isDark),
                        const SizedBox(height: 24),

                        // Preferences section
                        _SectionLabel(t: t, label: 'PREFERENCES'),
                        const SizedBox(height: 12),
                        _SettingsCard(
                          t: t,
                          items: [
                            _SettingItem(
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              desc: 'Push & in-app alerts',
                              value: preferences.notificationsEnabled,
                              onChanged: (value) => _savePreference(
                                () =>
                                    preferences.setNotificationsEnabled(value),
                              ),
                            ),
                            _SettingItem(
                              icon: Icons.vibration_rounded,
                              label: 'Haptic Feedback',
                              desc: 'Vibration responses',
                              value: preferences.hapticEnabled,
                              onChanged: (value) => _savePreference(
                                () => preferences.setHapticEnabled(value),
                              ),
                            ),
                            _SettingItem(
                              icon: Icons.bluetooth_rounded,
                              label: 'Auto-Connect',
                              desc: 'Connect on app launch',
                              value: preferences.autoConnectEnabled,
                              onChanged: (value) => _savePreference(
                                () => preferences.setAutoConnectEnabled(value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SignLangRow(t: t),
                        const SizedBox(height: 20),

                        // Settings
                        _SectionLabel(t: t, label: 'SETTINGS'),
                        const SizedBox(height: 12),
                        _QuickLinksCard(t: t),
                        const SizedBox(height: 24),

                        // Sign Out
                        AppButton(
                          variant: AppButtonVariant.destructive,
                          size: AppButtonSize.lg,
                          width: double.infinity,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          // Sign Out — clears session then navigates to login
                          onPressed: () async {
                            final auth = AuthProviderScope.of(context);
                            await auth.logout();
                            toast.success(title: 'Signed out');
                            if (context.mounted) context.go(AppRoutes.login);
                          },
                          child: const Text('Sign Out'),
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

class _ProfileCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  const _ProfileCard({required this.t, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final auth = AuthProviderScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    t.primary.withValues(alpha: isDark ? 0.07 : 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: _Orb(color: t.accent.withValues(alpha: 0.08), size: 120),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [t.primary, t.primaryGlow],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.primaryGlow.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 28,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // User name from AuthProvider (or 'User' fallback)
                          Text(
                            auth.userName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                              letterSpacing: -0.2,
                            ),
                          ),
                          // User email from AuthProvider
                          Text(
                            auth.userEmail.isNotEmpty ? auth.userEmail : '—',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.mutedForeground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  width: double.infinity,
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  child: const Text('Edit Profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });
}

class _SettingsCard extends StatelessWidget {
  final AppColorTokens t;
  final List<_SettingItem> items;
  const _SettingsCard({required this.t, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Container(
            decoration: i < items.length - 1
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        size: 16,
                        color: t.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.foreground,
                          ),
                        ),
                        Text(
                          item.desc,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(value: item.value, onChanged: item.onChanged),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  final AppColorTokens t;
  const _QuickLinksCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final links = ProfileScreen._quickLinks;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: links.asMap().entries.map((e) {
          final i = e.key;
          final link = e.value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (link.path.isNotEmpty) context.push(link.path);
            },
            child: Container(
              decoration: i < links.length - 1
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: t.border.withValues(alpha: 0.3),
                        ),
                      ),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.muted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          link.icon,
                          size: 16,
                          color: t.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            link.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.foreground,
                            ),
                          ),
                          Text(
                            link.desc,
                            style: TextStyle(
                              fontSize: 11,
                              color: t.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: t.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SignLangRow extends StatelessWidget {
  final AppColorTokens t;
  const _SignLangRow({required this.t});

  void _showPicker(BuildContext context) {
    final prefs = PreferencesScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      useRootNavigator: true,
      builder: (ctx) {
        return _SignLangSheet(prefs: prefs, t: t);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.language_rounded,
                    size: 16,
                    color: t.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign Language',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.foreground,
                      ),
                    ),
                    Text(
                      prefs.signLanguageFullName,
                      style: TextStyle(fontSize: 11, color: t.mutedForeground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prefs.signLanguageLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: t.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignLangSheet extends StatefulWidget {
  final PreferencesProvider prefs;
  final AppColorTokens t;
  const _SignLangSheet({required this.prefs, required this.t});
  @override
  State<_SignLangSheet> createState() => _SignLangSheetState();
}

class _SignLangSheetState extends State<_SignLangSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.prefs.signLanguage;
  }

  static const _options = [
    (
      code: kSignLangAsl,
      label: 'ASL',
      full: 'American Sign Language',
      badge: 'A',
    ),
    (
      code: kSignLangArsl,
      label: 'ArSL',
      full: 'Arabic Sign Language',
      badge: 'أ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.border.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.translate_rounded, size: 15, color: t.accent),
              ),
              const SizedBox(width: 10),
              Text(
                'Sign language',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: t.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your preferred sign language for translation and practice.',
            style: TextStyle(
              fontSize: 12,
              color: t.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ..._options.map((opt) {
            final sel = _selected == opt.code;
            return GestureDetector(
              onTap: () async {
                setState(() => _selected = opt.code);
                final saved = await widget.prefs.setSignLanguage(opt.code);
                if (!context.mounted) return;
                if (saved) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _selected = widget.prefs.signLanguage);
                  toast.error(
                    title: 'Language not saved',
                    description: 'Your previous language was restored.',
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? t.accent : t.border.withValues(alpha: 0.2),
                    width: sel ? 2 : 0.5,
                  ),
                  color: sel ? t.accent.withValues(alpha: 0.07) : t.card,
                ),
                child: Row(
                  children: [
                    // Flag chip
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sel
                            ? t.background
                            : t.background.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: t.border.withValues(alpha: 0.15),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt.badge,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: sel ? t.accent : t.mutedForeground,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Labels
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: sel ? t.accent : t.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.full,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Check indicator
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: sel ? 1 : 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: t.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
