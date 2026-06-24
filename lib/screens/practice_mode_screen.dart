import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../components/app_async_state.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../models/load_status.dart';
import '../services/glove_state_provider.dart';
import '../services/practice_controller.dart';
import '../services/preferences_provider.dart';
import '../app_routes.dart';

class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({super.key, @visibleForTesting this.controller});

  /// Test-only injection point. Production builds create their own controller;
  /// tests can pass one backed by a mock repository for deterministic content.
  final PracticeController? controller;

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  late final PracticeController _controller;
  late final bool _ownsController;
  String? _loadedLanguage;

  static const _difficultyMeta = {
    'Easy': (text: 'Easy', fgHex: 0xFF22C55E, bgHex: 0x1A22C55E),
    'Medium': (text: 'Medium', fgHex: 0xFF6C8AFF, bgHex: 0x1A6C8AFF),
    'Hard': (text: 'Hard', fgHex: 0xFFEF4444, bgHex: 0x1AEF4444),
  };

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = (widget.controller ?? PracticeController())
      ..addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = PreferencesScope.of(context).ttsLocale;
    if (_loadedLanguage == language) return;
    _loadedLanguage = language;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load(language);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    // Only dispose the controller we created; an injected one is owned by the caller.
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _showNoGloveDialog(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 20,
              color: t.destructive,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'No Glove Connected',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.foreground,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'No glove connected. Please pair your IntelliGlove device first.',
          style: TextStyle(fontSize: 13, color: t.mutedForeground, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: t.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.profileDevicePairing);
            },
            child: Text(
              'Pair Device',
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
                // Top bar — icon box on left, no back arrow (main service page)
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
                          color: const Color(0x1A6C8AFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.school_rounded,
                            size: 18,
                            color: Color(0xFF6C8AFF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Practice Mode',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.foreground,
                              ),
                            ),
                            Text(
                              'Sign Learning',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: t.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                    child: _buildPhaseContent(context, t, isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(
    BuildContext context,
    AppColorTokens t,
    bool isDark,
  ) {
    if (_controller.status == LoadStatus.loading ||
        _controller.status == LoadStatus.initial) {
      return const AppLoadingState(message: 'Loading practice content...');
    }
    if (_controller.status == LoadStatus.error) {
      return AppErrorState(
        message: _controller.error ?? 'Practice content could not be loaded.',
        onAction: _controller.retryLoad,
      );
    }
    if (_controller.status == LoadStatus.empty) {
      return const AppEmptyState(
        icon: Icons.school_outlined,
        message: 'No practice signs are available for this language.',
      );
    }
    switch (_controller.phase) {
      case PracticePhase.select:
        return _buildSelectPhase(context, t, isDark);
      case PracticePhase.practice:
        return _buildPracticePhase(context, t, isDark);
      case PracticePhase.result:
        return _buildResultPhase(context, t, isDark);
    }
  }

  Widget _buildSelectPhase(
    BuildContext context,
    AppColorTokens t,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            Flexible(
              child: Text(
                'PRACTICE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Learn Signs',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: t.foreground,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select a gesture to practice and get real-time feedback',
          style: TextStyle(fontSize: 13, color: t.mutedForeground),
        ),
        const SizedBox(height: 24),

        // Stats
        Row(
          children: [
            _StatChip(
              t: t,
              value: '${_controller.stats.totalPracticed}',
              label: 'Practiced',
            ),
            const SizedBox(width: 10),
            _StatChip(
              t: t,
              value: '${_controller.stats.averageAccuracy}%',
              label: 'Accuracy',
              accent: true,
            ),
            const SizedBox(width: 10),
            _StatChip(
              t: t,
              value: '${_controller.stats.streak}🔥',
              label: 'Streak',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Choose a Sign
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
            Flexible(
              child: Text(
                'CHOOSE A SIGN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.mutedForeground,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            // Fixed width per column; tiles size to their own content via Wrap so
            // they never overflow regardless of viewport width or text scale.
            // (The previous GridView used a hand-computed childAspectRatio that
            // summed font sizes as if they were line heights and clipped/overflowed.)
            // The -0.5 keeps a sub-pixel margin so float rounding can't push the
            // last tile onto a new row.
            final tileWidth =
                (constraints.maxWidth - (columns - 1) * spacing - 0.5) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _controller.signs.map((sign) {
                final meta = _difficultyMeta[sign.difficulty]!;
                return SizedBox(
                  width: tileWidth,
                  child: GestureDetector(
                    onTap: () {
                      if (!GloveStateScope.of(context).isConnected) {
                        _showNoGloveDialog(context);
                        return;
                      }
                      _controller.start(sign);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
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
                          Text(
                            sign.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sign.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(meta.bgHex),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sign.difficulty,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(meta.fgHex),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),

        // Recent Practice
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
            Flexible(
              child: Text(
                'RECENT PRACTICE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.mutedForeground,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _controller.history.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Container(
                decoration: i < _controller.history.length - 1
                    ? BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: t.border.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                            Icons.back_hand_outlined,
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
                              item.signName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: t.foreground,
                              ),
                            ),
                            Text(
                              _practiceDateLabel(item.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: t.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item.accuracy}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: item.accuracy >= 90 ? t.success : t.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticePhase(
    BuildContext context,
    AppColorTokens t,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          _controller.selectedSign!.emoji,
          style: const TextStyle(fontSize: 64),
        ),
        const SizedBox(height: 16),
        Text(
          'Practice: ${_controller.selectedSign!.name}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: t.foreground,
          ),
        ),
        Text(
          'Perform the gesture now',
          style: TextStyle(fontSize: 13, color: t.mutedForeground),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.accent.withValues(alpha: 0.2)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                t.primary.withValues(alpha: isDark ? 0.07 : 0.03),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: _controller.isPracticing
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: t.accent,
                          backgroundColor: t.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Analyzing your gesture...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.mutedForeground,
                        ),
                      ),
                      Text(
                        'Hold the sign steady',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.mutedForeground,
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.muted.withValues(alpha: 0.25),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.track_changes_rounded,
                        size: 32,
                        color: t.mutedForeground,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPhase(
    BuildContext context,
    AppColorTokens t,
    bool isDark,
  ) {
    final result = _controller.result!;
    final accuracy = result.accuracy;
    final correct = result.correct;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: correct
                ? t.success.withValues(alpha: 0.1)
                : t.destructive.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 40,
              color: correct ? t.success : t.destructive,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          correct ? 'Great Job!' : 'Almost There!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: t.foreground,
          ),
        ),
        Text(
          _controller.selectedSign!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: t.mutedForeground),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.accent.withValues(alpha: 0.2)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                t.primary.withValues(alpha: isDark ? 0.07 : 0.03),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            children: [
              Text(
                '$accuracy%',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: correct ? t.success : t.accent,
                  letterSpacing: -1.0,
                ),
              ),
              Text(
                'ACCURACY',
                style: TextStyle(
                  fontSize: 10,
                  color: t.mutedForeground,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.muted.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  result.suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    color: t.mutedForeground,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.outline,
                size: AppButtonSize.lg,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                onPressed: _controller.retry,
                child: const Text('Retry'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.hero,
                size: AppButtonSize.lg,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                onPressed: _controller.cancel,
                child: const Text('New Sign'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _practiceDateLabel(DateTime createdAt) {
  final now = DateTime.now();
  final date = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final today = DateTime(now.year, now.month, now.day);
  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
}

class _StatChip extends StatelessWidget {
  final AppColorTokens t;
  final String value;
  final String label;
  final bool accent;
  const _StatChip({
    required this.t,
    required this.value,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: accent ? t.accent : t.foreground,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: t.mutedForeground,
                letterSpacing: 0.8,
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
