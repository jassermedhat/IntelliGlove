import 'package:flutter/widgets.dart';
import 'dart:math' as math;

class AppLayout {
  AppLayout._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < 360;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  static double horizontalPadding(BuildContext context) {
    if (isTablet(context)) return 32;
    if (isCompact(context)) return 16;
    return 20;
  }

  static double topBarHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(64, scaler.scale(15) + scaler.scale(10) + 20);
  }

  static double bottomNavHeight(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(10);
    return math.max(64, 20 + 4 + labelHeight + 16);
  }

  static double bottomNavClearance(BuildContext context) {
    return bottomNavHeight(context) + MediaQuery.paddingOf(context).bottom + 24;
  }

  static double toastBottomOffset(
    BuildContext context, {
    required bool hasBottomNavigation,
  }) {
    final media = MediaQuery.of(context);
    final obstruction = math.max(media.padding.bottom, media.viewInsets.bottom);
    final textScaleExtra = ((media.textScaler.scale(16) - 16) * 0.75).clamp(
      0.0,
      16.0,
    );
    return obstruction +
        (hasBottomNavigation ? bottomNavHeight(context) + 16 : 0) +
        12 +
        textScaleExtra;
  }
}
