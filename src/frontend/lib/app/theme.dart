import 'package:flutter/material.dart';

import '../shared/widgets/brand.dart';

/// The two app themes, chosen by each user in Preferências (dark by default).
/// Dark: deep navy surfaces (not pure black) with the teal brand accent.
/// Light: cool off-white background, white cards and a deeper teal, so text and icons
/// keep their contrast.
abstract final class AppTheme {
  static final _darkColors =
      ColorScheme.fromSeed(
        seedColor: BrandColors.teal,
        brightness: Brightness.dark,
      ).copyWith(
        primary: BrandColors.teal,
        onPrimary: const Color(0xFF00201C),
        primaryContainer: const Color(0xFF16423F),
        onPrimaryContainer: const Color(0xFFB8F5EC),
        secondary: const Color(0xFF9D97FF),
        onSecondary: const Color(0xFF1A1550),
        secondaryContainer: const Color(0xFF2C2A5C),
        onSecondaryContainer: const Color(0xFFE2DFFF),
        tertiary: const Color(0xFFF2B455),
        onTertiary: const Color(0xFF3D2700),
        tertiaryContainer: const Color(0xFF4A3613),
        onTertiaryContainer: const Color(0xFFFFDDAE),
        surface: const Color(0xFF0D1220),
        onSurface: const Color(0xFFE4E7F0),
        onSurfaceVariant: const Color(0xFFA2A9BC),
        surfaceContainerLowest: const Color(0xFF090D18),
        surfaceContainerLow: const Color(0xFF111728),
        surfaceContainer: const Color(0xFF161D30),
        surfaceContainerHigh: const Color(0xFF1C2439),
        surfaceContainerHighest: const Color(0xFF252E46),
        outline: const Color(0xFF5A6380),
        outlineVariant: const Color(0xFF2B3450),
      );

  static final _lightColors =
      ColorScheme.fromSeed(
        seedColor: BrandColors.teal,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF00796B),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFC6F0E9),
        onPrimaryContainer: const Color(0xFF00201C),
        secondary: const Color(0xFF5B52E0),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFE4E1FF),
        onSecondaryContainer: const Color(0xFF1A1550),
        tertiary: const Color(0xFF9A5F00),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFFFE2B8),
        onTertiaryContainer: const Color(0xFF3D2700),
        surface: const Color(0xFFF4F6FB),
        onSurface: const Color(0xFF161B29),
        onSurfaceVariant: const Color(0xFF556079),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFFFFFF),
        surfaceContainer: Colors.white,
        surfaceContainerHigh: const Color(0xFFEDF0F7),
        surfaceContainerHighest: const Color(0xFFE2E6EF),
        outline: const Color(0xFF7A8399),
        outlineVariant: const Color(0xFFD6DBE6),
      );

  static final dark = _build(_darkColors);
  static final light = _build(_lightColors);

  static ThemeData _build(ColorScheme colors) {
    final radius = BorderRadius.circular(12);
    final base = ThemeData(colorScheme: colors);
    // Only weights here: font sizes are merged in later by Theme.of (localized geometry).
    final text = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    WidgetStateProperty<TextStyle?> navLabel(TextStyle? style) =>
        WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return style?.copyWith(
            color: selected ? colors.primary : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        });

    return base.copyWith(
      scaffoldBackgroundColor: colors.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: navLabel(text.labelMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: colors.outline),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        // No shadow: on the dark surface it reads as a black outline.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: colors.outlineVariant),
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.primaryContainer,
          selectedForegroundColor: colors.onPrimaryContainer,
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      // Account menu: a hairline border and a faint shadow (a strong one reads as a black outline).
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(2),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.2),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
    );
  }
}
