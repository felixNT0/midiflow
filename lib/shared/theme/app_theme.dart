import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// MIDIFlow design tokens — "studio luxury": deep charcoal, champagne gold,
/// warm neutrals, generous radii and short, decisive motion.
abstract final class AppColors {
  // Dark palette
  static const darkBackground = Color(0xFF0A0A0D);
  static const darkSurface = Color(0xFF131318);
  static const darkRaised = Color(0xFF1A1A21);
  static const darkHighest = Color(0xFF232329);
  static const darkInk = Color(0xFFF4F1EC);
  static const darkMuted = Color(0xFF9A97A3);
  static const darkGold = Color(0xFFD8B98A);
  static const darkGoldDeep = Color(0xFF8A6A45);
  static const darkOnGold = Color(0xFF1B1409);

  // Light palette
  static const lightBackground = Color(0xFFF5F3EE);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFEFEBE3);
  static const lightHighest = Color(0xFFE4DFD4);
  static const lightInk = Color(0xFF1C1B17);
  static const lightMuted = Color(0xFF6E6A60);
  static const lightGold = Color(0xFF9A7B4F);
  static const lightGoldDeep = Color(0xFF7A5F39);
  static const lightOnGold = Color(0xFFFBF7EF);
}

/// Shared motion vocabulary. Keep interactions under ~300 ms so the surface
/// feels immediate; use [slow] only for large layout changes.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  static const curve = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutQuart;
  static const standard = Curves.easeInOutCubic;
}

/// Builds the app theme for a given brightness.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme : _lightScheme;
    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.92)
            : AppColors.lightBackground.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkRaised : AppColors.lightRaised,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkRaised : AppColors.lightRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        elevation: 0,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.14),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkHighest : AppColors.lightInk,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkInk : AppColors.lightOnGold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkHighest : AppColors.lightInk,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: isDark ? AppColors.darkInk : AppColors.lightOnGold,
          fontSize: 12,
        ),
      ),
      textTheme: _textTheme(scheme),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displaySmall: TextStyle(
        color: scheme.onSurface,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      headlineSmall: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      titleLarge: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: scheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      bodyLarge: TextStyle(color: scheme.onSurface, fontSize: 15),
      bodyMedium: TextStyle(color: scheme.onSurface, fontSize: 14),
      bodySmall: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        letterSpacing: 0.1,
      ),
      labelLarge: TextStyle(
        color: scheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      labelMedium: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
      labelSmall: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
      ),
    );
  }

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkGold,
    onPrimary: AppColors.darkOnGold,
    primaryContainer: Color(0xFF3A2E1C),
    onPrimaryContainer: AppColors.darkGold,
    secondary: AppColors.darkMuted,
    onSecondary: AppColors.darkBackground,
    secondaryContainer: AppColors.darkRaised,
    onSecondaryContainer: AppColors.darkInk,
    tertiary: AppColors.darkGoldDeep,
    onTertiary: AppColors.darkInk,
    error: Color(0xFFE08A7A),
    onError: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkInk,
    onSurfaceVariant: AppColors.darkMuted,
    outline: Color(0xFF3A3A44),
    outlineVariant: Color(0xFF2A2A33),
    shadow: Colors.black,
    scrim: Colors.black54,
    inverseSurface: AppColors.darkInk,
    onInverseSurface: AppColors.darkBackground,
    inversePrimary: AppColors.darkGoldDeep,
    surfaceTint: Colors.transparent,
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lightGold,
    onPrimary: AppColors.lightOnGold,
    primaryContainer: Color(0xFFE9DCC3),
    onPrimaryContainer: AppColors.lightGoldDeep,
    secondary: AppColors.lightMuted,
    onSecondary: AppColors.lightSurface,
    secondaryContainer: AppColors.lightRaised,
    onSecondaryContainer: AppColors.lightInk,
    tertiary: AppColors.lightGoldDeep,
    onTertiary: AppColors.lightOnGold,
    error: Color(0xFFB0563F),
    onError: AppColors.lightSurface,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightInk,
    onSurfaceVariant: AppColors.lightMuted,
    outline: Color(0xFFD8D2C4),
    outlineVariant: Color(0xFFE3DDD0),
    shadow: Color(0x33000000),
    scrim: Colors.black38,
    inverseSurface: AppColors.lightInk,
    onInverseSurface: AppColors.lightBackground,
    inversePrimary: AppColors.lightGold,
    surfaceTint: Colors.transparent,
  );
}
