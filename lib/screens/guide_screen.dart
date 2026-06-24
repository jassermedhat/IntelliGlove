// guide_screen.dart
// User guide and tutorial for IntelliGlove.

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/app_top_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────────────────────────────────────

class _Section {
  final String id;
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final List<_Step> steps;

  const _Section({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
  });
}

class _Step {
  final String title;
  final String detail;
  const _Step(this.title, this.detail);
}

const _kSections = [
  _Section(
    id: 'getting-started',
    category: 'SETUP',
    title: 'Getting Started',
    description: 'Prepare the app for an approved IntelliGlove integration.',
    icon: Icons.bolt_rounded,
    steps: [
      _Step(
        'Check the hardware guide',
        'Charge and power on the glove according to its approved hardware documentation.',
      ),
      _Step(
        'Enable Bluetooth',
        'Enable Bluetooth and grant the permissions requested by the app.',
      ),
      _Step(
        'Open Device Pairing',
        'In the app go to Profile → Devices → Pair Device and tap "Scan".',
      ),
      _Step(
        'Select your device',
        'Physical discovery requires the approved BLE UUID and packet contract to be configured in this build.',
      ),
    ],
  ),
  _Section(
    id: 'gesture-translate',
    category: 'FEATURES',
    title: 'Gesture Translation',
    description: 'Translate validated sensor windows after glove integration.',
    icon: Icons.sign_language_rounded,
    steps: [
      _Step(
        'Open Translate',
        'Tap "Translate" on the Services tab or from the Home screen.',
      ),
      _Step(
        'Wear the glove snugly',
        'Ensure all sensors make contact with your fingers.',
      ),
      _Step(
        'Perform a gesture',
        'Validated sensor windows are sent to the active model and the result appears in the output card.',
      ),
      _Step(
        'Speak output',
        'Tap the Speak button to have the app read the translation aloud.',
      ),
    ],
  ),
  _Section(
    id: 'practice-mode',
    category: 'FEATURES',
    title: 'Practice Mode',
    description: 'Review model feedback when an approved glove and model are available.',
    icon: Icons.school_rounded,
    steps: [
      _Step(
        'Choose a sign',
        'Open Practice Mode and pick a gesture from the grid.',
      ),
      _Step(
        'Follow the prompt',
        'Perform the gesture when "Analyzing…" appears on screen.',
      ),
      _Step(
        'Review your score',
        'Treat confidence as model output, not as a certified measure of signing accuracy.',
      ),
      _Step(
        'Repeat or switch',
        'Tap Retry for more attempts or New Sign to choose another gesture.',
      ),
    ],
  ),
  _Section(
    id: 'sos-emergency',
    category: 'SAFETY',
    title: 'SOS Emergency Mode',
    description:
        'Prepare a device-local emergency record with an optional location snapshot.',
    icon: Icons.shield_rounded,
    steps: [
      _Step(
        'Add emergency contacts',
        'Go to SOS → tap Edit beside "Emergency Contacts".',
      ),
      _Step(
        'Activate via app',
        'Press and hold the red SOS button for 3 seconds to prepare the local record.',
      ),
      _Step(
        'Contact someone yourself',
        'The app does not send SMS messages or contact responders; use your phone to call or message a contact.',
      ),
      _Step(
        'Cancel',
        'Tap Cancel before the 3-second countdown ends to abort.',
      ),
    ],
  ),
  _Section(
    id: 'smart-home',
    category: 'FEATURES',
    title: 'Smart Home Control',
    description: 'Control your IoT devices with hand gestures.',
    icon: Icons.home_rounded,
    steps: [
      _Step(
        'Connect devices',
        'Tap the + button in Smart Home to add a new device.',
      ),
      _Step(
        'Toggle with gestures',
        'Pre-programmed gestures toggle lights, fans, and thermostats.',
      ),
      _Step(
        'Manual toggle',
        'Tap the toggle on any device card to switch it on or off.',
      ),
    ],
  ),
  _Section(
    id: 'health',
    category: 'HEALTH',
    title: 'Health Monitoring',
    description:
        'Your glove monitors heart rate, blood oxygen, and emotion in real time.',
    icon: Icons.favorite_rounded,
    steps: [
      _Step(
        'Wear properly',
        'The heart-rate sensor is on the inner wrist pad — keep it flat against your skin.',
      ),
      _Step('View vitals', 'Open Health from Services to see live readings.'),
      _Step(
        'Emotion detection',
        'Galvanic skin response sensors detect stress, happiness, and more.',
      ),
    ],
  ),
  _Section(
    id: 'battery-tips',
    category: 'TIPS',
    title: 'Battery & Care',
    description: 'Get the most out of your IntelliGlove battery life.',
    icon: Icons.battery_charging_full_rounded,
    steps: [
      _Step(
        'Average battery life',
        '8–10 hours with all sensors active; up to 18 hours in standby.',
      ),
      _Step(
        'Charging tips',
        'Charge before it drops below 10% to preserve cell longevity.',
      ),
      _Step(
        'Storage',
        'Store in the case when not in use to protect sensors and contacts.',
      ),
      _Step(
        'Firmware updates',
        'Regular updates often include battery efficiency improvements.',
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final Set<String> _expanded = {};

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 300),
          ),
          Positioned(
            bottom: 200,
            left: -80,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 220),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────
                AppTopBar(
                  title: 'User Guide',
                  subtitle: 'How it works',
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: t.accent,
                      ),
                    ),
                  ),
                  showBackButton: false,
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
                              'GUIDE',
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
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                              height: 1.1,
                              letterSpacing: -0.3,
                            ),
                            children: [
                              const TextSpan(text: 'IntelliGlove\n'),
                              TextSpan(
                                text: 'User Guide',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: t.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Everything you need to know to get the most out of your device.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Quick stats
                        Row(
                          children: [
                            _StatBadge(
                              t: t,
                              icon: Icons.layers_rounded,
                              label: '${_kSections.length} Sections',
                            ),
                            const SizedBox(width: 10),
                            _StatBadge(
                              t: t,
                              icon: Icons.checklist_rounded,
                              label:
                                  '${_kSections.fold(0, (sum, s) => sum + s.steps.length)} Steps',
                            ),
                            const SizedBox(width: 10),
                            _StatBadge(
                              t: t,
                              icon: Icons.timer_outlined,
                              label: '5 min read',
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Sections accordion
                        ..._kSections.map(
                          (section) => _SectionCard(
                            t: t,
                            isDark: isDark,
                            section: section,
                            isExpanded: _expanded.contains(section.id),
                            onToggle: () => _toggle(section.id),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Footer tip
                        Container(
                          width: double.infinity,
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
                                t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
                                t.primary.withValues(
                                  alpha: isDark ? 0.1 : 0.05,
                                ),
                              ],
                            ),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: t.mutedForeground,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: '💡 '),
                                TextSpan(
                                  text: 'Need more help? ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.foreground,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'Visit the FAQ section in your Profile for answers to common questions.',
                                ),
                              ],
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
//  Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final _Section section;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SectionCard({
    required this.t,
    required this.isDark,
    required this.section,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? t.accent.withValues(alpha: 0.3)
              : t.border.withValues(alpha: 0.4),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? t.accent.withValues(alpha: 0.12)
                          : t.muted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        section.icon,
                        size: 20,
                        color: isExpanded ? t.accent : t.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          section.category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isExpanded ? t.accent : t.mutedForeground,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          section.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          section.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isExpanded ? t.accent : t.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded steps
          if (isExpanded) ...[
            Container(height: 1, color: t.border.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: section.steps.asMap().entries.map((e) {
                  final idx = e.key;
                  final step = e.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx < section.steps.length - 1 ? 14 : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: t.accent,
                              ),
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
                                step.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.foreground,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                step.detail,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.mutedForeground,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final AppColorTokens t;
  final IconData icon;
  final String label;
  const _StatBadge({required this.t, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: t.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
