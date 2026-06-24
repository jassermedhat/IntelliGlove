// help_feedback_screen.dart
// Help & Feedback screen — support categories with interactive topic sheets,
// inline feedback/bug form, and a link to the FAQ screen.

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/app_top_bar.dart';
import '../components/toast.dart';
import '../repositories/reports_repository.dart';
import '../app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────────────────────────────────────

class _HelpTopic {
  final IconData icon;
  final String label;
  final String desc;
  final String body;
  final List<String> steps;
  final String? actionLabel;
  final String? actionRoute;

  const _HelpTopic({
    required this.icon,
    required this.label,
    required this.desc,
    required this.body,
    this.steps = const [],
    this.actionLabel,
    this.actionRoute,
  });
}

const _kTopics = [
  _HelpTopic(
    icon: Icons.play_circle_outline_rounded,
    label: 'Getting Started',
    desc: 'First-time setup and pairing',
    body:
        'Welcome to IntelliGlove. Account-backed features work after sign-in; live glove features also require the production BLE hardware contract.',
    steps: [
      'Sign in and verify that the backend services you need are available.',
      'Open the app, go to Profile → Devices → Pair Device, and tap Scan for Devices.',
      'A physical glove can connect only after its approved BLE UUIDs and packet format are integrated.',
    ],
    actionLabel: 'Open User Guide',
    actionRoute: '/services/guide',
  ),
  _HelpTopic(
    icon: Icons.bluetooth_searching_rounded,
    label: 'Device Issues',
    desc: 'Pairing, connectivity, firmware',
    body:
        'Having trouble connecting? Check the phone and app first, then consult the hardware documentation for device-specific indicators.',
    steps: [
      'Ensure Bluetooth and the required permissions are enabled on your phone.',
      'Toggle Bluetooth off and back on, then re-scan from Profile → Devices → Pair Device.',
      'Confirm that this build has been configured with the approved glove BLE service and packet contract.',
      'Use only the reset and LED instructions supplied with your physical glove hardware.',
    ],
    actionLabel: 'Go to Devices',
    actionRoute: '/profile/devices',
  ),
  _HelpTopic(
    icon: Icons.translate_rounded,
    label: 'Translation',
    desc: 'Gesture recognition & accuracy',
    body: 'Get the most out of real-time gesture translation with these tips.',
    steps: [
      'Keep your glove sensors clean and ensure they make firm contact with your fingers.',
      'Perform gestures in front of you at a steady pace — avoid sudden jerky movements.',
      'Switch between ASL and ArSL in Profile → Preferences → Sign Language.',
    ],
  ),
  _HelpTopic(
    icon: Icons.shield_outlined,
    label: 'SOS & Safety',
    desc: 'Local emergency preparation',
    body:
        'SOS prepares a location snapshot and emergency-contact record on this device. It does not dispatch messages or contact responders.',
    steps: [
      'Open the SOS screen and tap Edit next to Emergency Contacts to add names and phone numbers.',
      'Allow location access when sending SOS so the local record can include your current position.',
      'Hold the on-screen SOS button for 3 seconds to prepare the local record.',
    ],
    actionLabel: 'Go to Privacy',
    actionRoute: '/profile/privacy-security',
  ),
  _HelpTopic(
    icon: Icons.account_circle_outlined,
    label: 'Account & Profile',
    desc: 'Edit profile, appearance, prefs',
    body:
        'Manage your personal information, appearance settings, and preferences from the Profile tab.',
    steps: [
      'Tap Edit Profile in the Profile tab to update your name, email, or avatar.',
      'Switch between Light and Dark mode using the toggle in Profile → Appearance.',
      'Change your sign language preference from Profile → Preferences → Sign Language.',
    ],
  ),
  _HelpTopic(
    icon: Icons.miscellaneous_services_rounded,
    label: 'Other',
    desc: 'Anything else',
    body:
        "Didn't find what you were looking for? Check the FAQ for quick answers or contact our support team directly.",
    steps: [],
    actionLabel: 'Open FAQ',
    actionRoute: '/profile/faq',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

enum _FormMode { feedback, bug }

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final _feedbackCtrl = TextEditingController();
  String? _selectedTopic;
  _FormMode _formMode = _FormMode.feedback;
  final ReportsRepository _reports = BackendReportsRepository();
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _setMode(_FormMode mode) {
    if (_formMode == mode) return;
    setState(() {
      _formMode = mode;
      _feedbackCtrl.clear();
    });
  }

  Future<void> _submit() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      toast.warning(
        title: 'Empty message',
        description: _formMode == _FormMode.feedback
            ? 'Please describe your feedback before submitting.'
            : 'Please describe the bug before submitting.',
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _reports.submit(
        type: _formMode.name,
        message: text,
        topic: _selectedTopic,
      );
    } catch (_) {
      if (mounted) {
        toast.error(
          title: 'Could not send report',
          description: 'Please check your connection and try again.',
        );
        setState(() => _submitting = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    toast.success(
      title: _formMode == _FormMode.feedback
          ? 'Feedback sent'
          : 'Bug report sent',
      description: _formMode == _FormMode.feedback
          ? "Thank you! We'll review your message shortly."
          : "Bug reported! We'll investigate and fix it as soon as possible.",
    );
    _feedbackCtrl.clear();
    setState(() => _selectedTopic = null);
  }

  void _showTopicSheet(BuildContext context, _HelpTopic topic) {
    final t = ThemeProviderScope.of(context).tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: t.border.withValues(alpha: 0.3)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(topic.icon, size: 20, color: t.accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          topic.label,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: t.foreground,
                          ),
                        ),
                        Text(
                          topic.desc,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                topic.body,
                style: TextStyle(
                  fontSize: 13,
                  color: t.mutedForeground,
                  height: 1.5,
                ),
              ),
              if (topic.steps.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STEPS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: t.mutedForeground,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...topic.steps.asMap().entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: t.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.foreground,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (topic.actionLabel != null && topic.actionRoute != null) ...[
                const SizedBox(height: 8),
                AppButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(topic.actionRoute!);
                  },
                  child: Text(topic.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    final bool isBug = _formMode == _FormMode.bug;
    final String hintText = isBug
        ? 'Describe the bug — what happened, expected behaviour, and steps to reproduce…'
        : 'Tell us how we can improve the app, or share your thoughts…';

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
                        'Help & Feedback',
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
                              'SUPPORT',
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
                          'Help & Feedback',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let us know how we can help you',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Help categories
                        _SectionLabel(t: t, label: 'HELP TOPICS'),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final scaler = MediaQuery.textScalerOf(context);
                            final columns =
                                constraints.maxWidth < 360 ||
                                    scaler.scale(12) > 18
                                ? 1
                                : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    mainAxisExtent: scaler.scale(12) + 32,
                                  ),
                              itemCount: _kTopics.length,
                              itemBuilder: (_, i) {
                                final topic = _kTopics[i];
                                final selected = _selectedTopic == topic.label;
                                return GestureDetector(
                                  onTap: () {
                                    setState(
                                      () => _selectedTopic = selected
                                          ? null
                                          : topic.label,
                                    );
                                    _showTopicSheet(context, topic);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? t.accent.withValues(alpha: 0.1)
                                          : t.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? t.accent
                                            : t.border.withValues(alpha: 0.4),
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          topic.icon,
                                          size: 16,
                                          color: selected
                                              ? t.accent
                                              : t.mutedForeground,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            topic.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: selected
                                                  ? t.accent
                                                  : t.foreground,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 12,
                                          color: t.mutedForeground,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // FAQ shortcut
                        _SectionLabel(t: t, label: 'QUICK HELP'),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.profileFaq),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: t.border.withValues(alpha: 0.4),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  t.primary.withValues(
                                    alpha: isDark ? 0.1 : 0.05,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: t.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.quiz_outlined,
                                      size: 22,
                                      color: t.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Browse FAQ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: t.foreground,
                                        ),
                                      ),
                                      Text(
                                        'Answers to the most common questions',
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
                                  size: 18,
                                  color: t.mutedForeground,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Feedback / Bug form
                        _SectionLabel(t: t, label: 'SEND MESSAGE'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Segmented control
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: t.muted.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: t.border.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _SegmentTab(
                                      t: t,
                                      label: 'Feedback',
                                      icon: Icons.chat_bubble_outline_rounded,
                                      isSelected: !isBug,
                                      onTap: () => _setMode(_FormMode.feedback),
                                    ),
                                    _SegmentTab(
                                      t: t,
                                      label: 'Bug Report',
                                      icon: Icons.bug_report_outlined,
                                      isSelected: isBug,
                                      selectedColor: t.destructive,
                                      onTap: () => _setMode(_FormMode.bug),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  key: ValueKey(_formMode),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isBug
                                          ? 'Report a Bug'
                                          : 'Share your thoughts',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: t.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isBug
                                          ? 'Help us fix issues by describing what went wrong.'
                                          : 'We read every message and use it to improve the app.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: t.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              AppInput(
                                controller: _feedbackCtrl,
                                hintText: hintText,
                                maxLines: 5,
                              ),
                              const SizedBox(height: 14),
                              AppButton(
                                variant: isBug
                                    ? AppButtonVariant.destructive
                                    : AppButtonVariant.accent,
                                size: AppButtonSize.lg,
                                width: double.infinity,
                                icon: Icon(
                                  isBug
                                      ? Icons.bug_report_outlined
                                      : Icons.send_rounded,
                                  size: 16,
                                ),
                                onPressed: _submitting ? null : _submit,
                                child: Text(
                                  isBug ? 'Submit Bug Report' : 'Send Feedback',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Contact info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Need direct support? Email us at support@intelliglove.com',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: t.mutedForeground,
                            ),
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
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentTab extends StatelessWidget {
  final AppColorTokens t;
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color? selectedColor;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.t,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? (selectedColor ?? t.accent) : t.mutedForeground;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? t.card : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: t.border.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
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
