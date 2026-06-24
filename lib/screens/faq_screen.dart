// faq_screen.dart
// Frequently Asked Questions for IntelliGlove.

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/app_top_bar.dart';
import '../app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _kFaqs = [
  _FaqItem(
    'How do I pair my IntelliGlove?',
    'Go to Profile → Devices → Pair Device and tap "Scan for Devices". Make sure your glove is powered on and within 10 meters. Select it from the list and confirm the pairing code on screen.',
  ),
  _FaqItem(
    'Why isn\'t my glove being detected?',
    'Ensure the glove is charged (LED pulses blue when on). Check that Bluetooth is enabled on your phone. Try toggling Bluetooth off and back on, then scan again.',
  ),
  _FaqItem(
    'How accurate is gesture translation?',
    'No production accuracy figure is claimed until an approved trained model is supplied and validated against its documented dataset. Confidence shown by the app is model output, not a certified accuracy measurement.',
  ),
  _FaqItem(
    'What does the SOS mode do exactly?',
    'SOS stores a prepared emergency record and an optional current-location snapshot locally on this device. It does not send SMS messages, continuously track you, contact responders, or trigger a physical glove.',
  ),
  _FaqItem(
    'How long does the battery last?',
    'Battery life and charging time depend on the physical glove revision. Use the specifications supplied with your approved hardware; the app does not measure or guarantee those figures.',
  ),
  _FaqItem(
    'Can I use the app without a glove connected?',
    'Live gesture translation requires a connected IntelliGlove. You can still review previous translations and use text-to-speech for saved text while offline.',
  ),
  _FaqItem(
    'How do I update the firmware?',
    'Go to Profile → Devices → Firmware Updates. This build shows a clearly labeled simulation; real firmware installation will be available after production OTA integration.',
  ),
  _FaqItem(
    'Is my health data stored online?',
    'Account-backed health records are stored in PostgreSQL under your Firebase identity. Onboarding, preferences, biometric settings, emergency contacts, and prepared SOS records remain device-local.',
  ),
  _FaqItem(
    'How do I add or edit emergency contacts?',
    'Open the SOS screen and tap "Edit" next to the Emergency Contacts section. You can add, remove, or reorder contacts from there.',
  ),
  _FaqItem(
    'Can I use the Smart Home features with any device?',
    'This build persists smart-home device records and requested state through the backend, but it does not include a Matter, Zigbee, or vendor control adapter for physical devices.',
  ),
  _FaqItem(
    'How do I reset the glove to factory settings?',
    'Factory-reset behavior is hardware-specific and is not defined by the app. Follow the instructions supplied with your approved glove revision.',
  ),
  _FaqItem(
    'Is the glove water resistant?',
    'The app does not assert a water-resistance rating. Check the certification and safety documentation supplied with your physical glove before exposing it to water.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final Set<int> _expanded = {};
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    final filtered = _searchQuery.isEmpty
        ? _kFaqs
        : _kFaqs
              .where(
                (f) =>
                    f.question.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    f.answer.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 260),
          ),
          Positioned(
            bottom: 200,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 200),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────
                AppTopBar(
                  showBackButton: true,
                  fallbackRoute: AppRoutes.profile,
                  title: 'FAQ',
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
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                            children: [
                              const TextSpan(text: 'Frequently\n'),
                              TextSpan(
                                text: 'Asked Questions',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: t.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find quick answers to the most common questions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Search bar
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: t.mutedForeground,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.foreground,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search questions…',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: t.mutedForeground,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: t.mutedForeground,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${filtered.length} question${filtered.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // FAQ list
                        if (filtered.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: t.mutedForeground.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results for "$_searchQuery"',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: t.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filtered.asMap().entries.map((e) {
                            final origIdx = _kFaqs.indexOf(e.value);
                            return _FaqCard(
                              t: t,
                              isDark: isDark,
                              item: e.value,
                              isExpanded: _expanded.contains(origIdx),
                              onToggle: () => _toggle(origIdx),
                            );
                          }),
                        const SizedBox(height: 20),

                        // Contact support footer
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
                                t.primary.withValues(
                                  alpha: isDark ? 0.1 : 0.05,
                                ),
                                t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.support_agent_rounded,
                                size: 28,
                                color: t.accent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Still have questions?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.foreground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Contact support at support@intelliglove.com',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.mutedForeground,
                                ),
                                textAlign: TextAlign.center,
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
//  FAQ card
// ─────────────────────────────────────────────────────────────────────────────

class _FaqCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final _FaqItem item;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _FaqCard({
    required this.t,
    required this.isDark,
    required this.item,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? t.accent.withValues(alpha: 0.3)
              : t.border.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isExpanded
                          ? t.accent
                          : t.mutedForeground.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.question,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isExpanded ? t.foreground : t.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isExpanded ? t.accent : t.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(height: 1, color: t.border.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 12, 16, 16),
              child: Text(
                item.answer,
                style: TextStyle(
                  fontSize: 12,
                  color: t.mutedForeground,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
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
