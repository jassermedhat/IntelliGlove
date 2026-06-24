// translate_screen.dart
// Disconnected-aware: shows OFFLINE state, empty text, inactive glove viz.
// Sign language (ASL/ArSL) drives TTS locale; Arabic text shows RTL.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/display.dart';
import '../components/glove_visualization.dart';
import '../components/translation_history_presenter.dart';
import '../models/load_status.dart';
import '../models/translation_record.dart';
import '../services/glove_state_provider.dart';
import '../services/preferences_provider.dart';
import '../app_routes.dart';
import '../services/translation_controller.dart';
import '../components/toast.dart';
import '../components/app_layout.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  // Starts empty — filled by the live glove stream in the real app.
  // When disconnected we keep whatever was last received (or empty on first open).
  bool? _lastConnected;
  String? _lastLanguageCode;
  TranslationController? _controller;

  // ── TTS ───────────────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= TranslationControllerScope.of(context);
  }

  @override
  void dispose() {
    _controller?.leavePage();
    super.dispose();
  }

  Future<void> _handleToggleSpeak(
    BuildContext ctx,
    bool isConnected,
    String ttsLocale,
  ) async {
    final controller = TranslationControllerScope.of(ctx);

    if (controller.isAutoSpeakActive) {
      await controller.stopAutoSpeak();
      return;
    }
    if (!isConnected) {
      _showPairDeviceAction(ctx);
      return;
    }
    await controller.startAutoSpeak();
  }

  Future<void> _handleRepeat(BuildContext ctx, String ttsLocale) async {
    final controller = TranslationControllerScope.of(ctx);
    final spoken = await controller.speak(ttsLocale);
    if (!spoken && ctx.mounted) {
      toast.error(
        title: 'Text-to-speech unavailable',
        description: controller.errorMessage,
      );
    }
  }

  void _showPairDeviceAction(BuildContext ctx) {
    toast.show(
      description: 'Connect your IntelliGlove to start translation.',
      actionLabel: 'Pair Device',
      onAction: () => ctx.push(AppRoutes.profileDevices),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final isConnected = GloveStateScope.of(context).isConnected;
    final controller = TranslationControllerScope.of(context);
    if (_lastConnected != isConnected) {
      _lastConnected = isConnected;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setConnected(isConnected);
      });
    }
    final prefs = PreferencesScope.of(context);
    final ttsLocale = prefs.ttsLocale;
    final isRtl = prefs.isRtl;
    if (_lastLanguageCode != ttsLocale) {
      _lastLanguageCode = ttsLocale;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setLanguage(ttsLocale);
      });
    }
    if (controller.historyStatus == LoadStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadHistory();
      });
    }
    final isLive = controller.isLive;
    final sessionNum = controller.activeSessionNumber;
    final stats = [
      (
        label: 'Session',
        value: sessionNum != null ? '#$sessionNum' : 'Off',
      ),
      (label: 'Letters', value: '${controller.translatedLettersCount}'),
      (label: 'Active', value: controller.isSessionActive ? 'Yes' : 'No'),
    ];

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 320),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5,
            left: -100,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 240),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
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
                          color: t.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.record_voice_over_rounded,
                            size: 18,
                            color: t.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Translate',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isLive
                                  ? 'Real-time'
                                  : (isConnected
                                        ? 'Session stopped'
                                        : 'Offline'),
                              style: TextStyle(
                                fontSize: 10,
                                color: isConnected
                                    ? t.mutedForeground
                                    : t.destructive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.horizontalPadding(context),
                      24,
                      AppLayout.horizontalPadding(context),
                      AppLayout.bottomNavClearance(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero split ────────────────────────────────────────
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isConnected ? t.accent : t.destructive,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Text(
                              isLive
                                  ? 'LIVE'
                                  : (isConnected ? 'READY' : 'OFFLINE'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isConnected ? t.accent : t.destructive,
                                letterSpacing: 2.0,
                              ),
                            ),
                            _PulsingDot(
                              color: isConnected ? t.success : t.destructive,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'DEMO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: t.accent,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Gesture Translation',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: t.mutedForeground,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLive
                              ? 'Your gestures are being translated in real-time.'
                              : (isConnected
                                    ? 'Start a session when you are ready to translate.'
                                    : 'Pair your IntelliGlove to begin live translation.'),
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Mini stats 3-col ──────────────────────────────────
                        AppButton(
                          width: double.infinity,
                          variant: controller.isSessionActive
                              ? AppButtonVariant.secondary
                              : AppButtonVariant.hero,
                          icon: Icon(
                            controller.isSessionActive
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          onPressed: () async {
                            if (!isConnected) {
                              _showPairDeviceAction(context);
                              return;
                            }
                            if (controller.isSessionActive) {
                              await controller.stop();
                            } else {
                              final started = await controller.start();
                              if (!started && mounted) {
                                toast.error(
                                  title: 'Translation unavailable',
                                  description: controller.errorMessage,
                                );
                              }
                            }
                          },
                          child: Text(
                            controller.isSessionActive
                                ? 'Stop Translation'
                                : 'Start Translation',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: stats
                              .map(
                                (s) => Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: s == stats.last ? 0 : 10,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: t.card,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: t.border.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.value,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: t.foreground,
                                          ),
                                        ),
                                        Text(
                                          s.label,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: t.mutedForeground,
                                            letterSpacing: 0.8,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 24),

                        // ── Translation output card ───────────────────────────
                        _TranslationOutputCard(
                          t: t,
                          isDark: isDark,
                          text: controller.text,
                          isAutoSpeakActive: controller.isAutoSpeakActive,
                          isConnected: isLive,
                          isRtl: isRtl,
                          onToggleSpeak: () => _handleToggleSpeak(
                            context,
                            isConnected,
                            ttsLocale,
                          ),
                          onRepeat: () => _handleRepeat(context, ttsLocale),
                        ),
                        const SizedBox(height: 24),

                        // ── Live / Paused Preview label ───────────────────────
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? t.accent.withValues(alpha: 0.6)
                                    : t.mutedForeground.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLive ? 'LIVE PREVIEW' : 'PAUSED PREVIEW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isConnected
                                    ? t.mutedForeground
                                    : t.mutedForeground.withValues(alpha: 0.5),
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: GloveVisualization(
                              size: GloveSize.lg,
                              isActive: isLive,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Recent translations ───────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
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
                                  'RECENT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: t.mutedForeground,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push(
                                AppRoutes.servicesTranslateHistory,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View all',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: t.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 12,
                                    color: t.accent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...controller.history
                            .take(3)
                            .map((item) => _RecentItem(t: t, item: item)),
                        const SizedBox(height: 16),

                        // ── Tip ───────────────────────────────────────────────
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
                                  text: 'Tip: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.foreground,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      'Keep your hand steady for better gesture recognition accuracy.',
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
//  Translation output card
// ─────────────────────────────────────────────────────────────────────────────

class _TranslationOutputCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final String text;
  final bool isAutoSpeakActive;
  final bool isConnected;
  final bool isRtl;
  final VoidCallback onToggleSpeak;
  final VoidCallback onRepeat;

  const _TranslationOutputCard({
    required this.t,
    required this.isDark,
    required this.text,
    required this.isAutoSpeakActive,
    required this.isConnected,
    required this.isRtl,
    required this.onToggleSpeak,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasText = text.trim().isNotEmpty;
    final String displayText = hasText
        ? text
        : (isConnected
              ? 'Listening for gestures…'
              : 'Waiting for a connected glove...');
    final Color textColor = hasText
        ? t.foreground
        : t.mutedForeground.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? t.accent.withValues(alpha: 0.2)
              : t.border.withValues(alpha: 0.4),
        ),
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
                    t.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -16,
            right: -16,
            child: _Orb(color: t.accent.withValues(alpha: 0.08), size: 80),
          ),
          // Left accent bar — dimmed when offline
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              color: isConnected
                  ? t.accent
                  : t.mutedForeground.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // 👈 pushes to edges
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  size: 14,
                                  color: isConnected
                                      ? t.accent
                                      : t.mutedForeground,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'TRANSLATION',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isConnected
                                          ? t.accent
                                          : t.mutedForeground,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isConnected) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.success,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Connected',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: t.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Translation text — RTL for Arabic
                Directionality(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 140),
                    alignment: Alignment.center,
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: hasText ? 40 : 18,
                        fontWeight: hasText ? FontWeight.w800 : FontWeight.w400,
                        color: textColor,
                        height: 1.3,
                        fontStyle: hasText
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      textAlign:
                          TextAlign.center, // always centered regardless of RTL
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: isAutoSpeakActive
                            ? AppButtonVariant.secondary
                            : AppButtonVariant.accent,
                        size: AppButtonSize.sm,
                        icon: Icon(
                          isAutoSpeakActive
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 16,
                        ),
                        onPressed: onToggleSpeak,
                        child: Text(isAutoSpeakActive ? 'Stop' : 'Speak'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton.icon(
                      icon: const Icon(Icons.repeat_rounded, size: 16),
                      variant: AppButtonVariant.outline,
                      onPressed: onRepeat,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Recent item row
// ─────────────────────────────────────────────────────────────────────────────

class _RecentItem extends StatelessWidget {
  final AppColorTokens t;
  final TranslationRecord item;
  const _RecentItem({required this.t, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, color: t.accent.withValues(alpha: 0.4)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formatTranslationTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(item.confidence * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: t.accent,
                        fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: 0.5 + _c.value * 0.5),
      ),
    ),
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
