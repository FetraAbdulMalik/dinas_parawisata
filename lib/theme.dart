import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const appDialogAnimationStyle = AnimationStyle(
  duration: Duration(milliseconds: 280),
  reverseDuration: Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class AppColors {
  static const green = Color(0xFF2B6A0A);
  static const background = Color(0xFFE9ECF1);
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B7280);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green)
        .copyWith(primary: AppColors.green),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
  );
}

List<BoxShadow> softShadow() => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
