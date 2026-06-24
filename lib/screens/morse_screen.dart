// morse_screen.dart
// Dialog uses showAppDialog() + AppDialogContent / AppDialogHeader from overlays.dart

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/overlays.dart';

class MorseScreen extends StatefulWidget {
  const MorseScreen({super.key});
  @override
  State<MorseScreen> createState() => _MorseScreenState();
}

class _MorseScreenState extends State<MorseScreen> {
  final String _morseSignal = '·− −··· −·−· −··';
  final String _translatedText = 'ABCD';
  bool _isSpeaking = false;

  static const _morseAlphabet = [
    (letter: 'A', code: '·−'),
    (letter: 'B', code: '−···'),
    (letter: 'C', code: '−·−·'),
    (letter: 'D', code: '−··'),
    (letter: 'E', code: '·'),
    (letter: 'F', code: '··−·'),
    (letter: 'G', code: '−−·'),
    (letter: 'H', code: '····'),
    (letter: 'I', code: '··'),
    (letter: 'J', code: '·−−−'),
    (letter: 'K', code: '−·−'),
    (letter: 'L', code: '·−··'),
    (letter: 'M', code: '−−'),
    (letter: 'N', code: '−·'),
    (letter: 'O', code: '−−−'),
    (letter: 'P', code: '·−−·'),
    (letter: 'Q', code: '−−·−'),
    (letter: 'R', code: '·−·'),
    (letter: 'S', code: '···'),
    (letter: 'T', code: '−'),
    (letter: 'U', code: '··−'),
    (letter: 'V', code: '···−'),
    (letter: 'W', code: '·−−'),
    (letter: 'X', code: '−··−'),
    (letter: 'Y', code: '−·−−'),
    (letter: 'Z', code: '−−··'),
  ];

  static const _howItems = [
    (label: 'Dot (·)', desc: 'Quick tap'),
    (label: 'Dash (−)', desc: 'Long press'),
    (label: 'Letter gap', desc: 'Pause briefly'),
    (label: 'Word gap', desc: 'Double pause'),
  ];

  void _showReference(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    showAppDialog(
      context: context,
      builder: (ctx) => AppDialogContent(
        maxWidth: 400,
        onClose: () => Navigator.of(ctx).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDialogHeader(
              title: const AppDialogTitle('Morse Code Reference'),
              description: const AppDialogDescription(
                'All letters with their Morse code patterns',
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 320 ? 3 : 4;
                final scaler = MediaQuery.textScalerOf(context);
                final tileHeight = scaler.scale(16) + scaler.scale(9) + 20;
                final tileWidth =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: tileWidth / tileHeight,
                  children: _morseAlphabet
                      .map(
                        (item) => Container(
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.letter,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: t.foreground,
                                ),
                              ),
                              Text(
                                item.code,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: t.mutedForeground,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
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
            top: -120,
            right: -120,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 320),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            left: -100,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 240),
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
                          color: t.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.radio_rounded,
                            size: 18,
                            color: t.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Morse Code',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                          Text(
                            'Tap signals',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.mutedForeground,
                            ),
                          ),
                        ],
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
                              'DECODER',
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
                              const TextSpan(text: 'Morse\n'),
                              TextSpan(
                                text: 'Communication',
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
                          'Tap-based morse signals decoded from your IntelliGlove.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Decoded output card
                        _DecodedCard(
                          t: t,
                          isDark: isDark,
                          morseSignal: _morseSignal,
                          translatedText: _translatedText,
                        ),
                        const SizedBox(height: 20),

                        // Controls
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                variant: _isSpeaking
                                    ? AppButtonVariant.secondary
                                    : AppButtonVariant.accent,
                                size: AppButtonSize.lg,
                                icon: Icon(
                                  _isSpeaking
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _isSpeaking = !_isSpeaking),
                                child: Text(_isSpeaking ? 'Pause' : 'Speak'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppButton(
                                variant: AppButtonVariant.outline,
                                size: AppButtonSize.lg,
                                icon: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 18,
                                ),
                                onPressed: () => _showReference(context),
                                child: const Text('Reference'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // How to use
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
                              'HOW TO USE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.mutedForeground,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final scaler = MediaQuery.textScalerOf(context);
                            final columns = constraints.maxWidth < 340 ? 1 : 2;
                            final tileHeight =
                                scaler.scale(12) + scaler.scale(10) + 28;
                            final tileWidth =
                                (constraints.maxWidth - (columns - 1) * 10) /
                                columns;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: tileWidth / tileHeight,
                              children: _howItems
                                  .map(
                                    (item) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.card,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: t.border.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: t.foreground,
                                            ),
                                          ),
                                          Text(
                                            item.desc,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: t.mutedForeground,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Tip
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
                                      'Practice with common words before moving to full conversations.',
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

class _DecodedCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final String morseSignal;
  final String translatedText;
  const _DecodedCard({
    required this.t,
    required this.isDark,
    required this.morseSignal,
    required this.translatedText,
  });

  @override
  Widget build(BuildContext context) {
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
                    t.primary.withValues(alpha: isDark ? 0.08 : 0.03),
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
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: t.accent),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.radio_rounded, size: 14, color: t.accent),
                    const SizedBox(width: 6),
                    Text(
                      'DECODED MESSAGE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'MORSE CODE',
                  style: TextStyle(
                    fontSize: 9,
                    color: t.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  morseSignal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ENGLISH',
                  style: TextStyle(
                    fontSize: 9,
                    color: t.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  translatedText,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: t.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.success,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Detected from glove tap gestures',
                      style: TextStyle(
                        fontSize: 10,
                        color: t.success,
                        fontWeight: FontWeight.w600,
                      ),
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
