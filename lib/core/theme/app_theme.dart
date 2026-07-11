import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const primary = Color(0xFF6E7F2B);
  static const lightBackground = Color(0xFFFAF8F2);
  static const lightText = Color(0xFF222222);
  static const lightMutedText = Color(0xFF777777);
  static const lightDivider = Color(0xFFECECEC);

  static const darkPrimary = Color(0xFFD1DC83);
  static const darkBackground = Color(0xFF15160F);
  static const darkSurface = Color(0xFF1E2018);
  static const darkText = Color(0xFFF3F0E8);
  static const darkMutedText = Color(0xFFC3BDAF);
  static const darkDivider = Color(0xFF3A3D32);

  static ThemeData light() {
    return _polish(
      FlexThemeData.light(
        scheme: FlexScheme.verdunHemlock,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
        blendLevel: 2,
        appBarStyle: FlexAppBarStyle.scaffoldBackground,
        subThemesData: _subThemes,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      ),
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    return _polish(
      FlexThemeData.dark(
        scheme: FlexScheme.verdunHemlock,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
        blendLevel: 4,
        appBarStyle: FlexAppBarStyle.scaffoldBackground,
        subThemesData: _subThemes,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      ),
      brightness: Brightness.dark,
    );
  }

  static const _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    defaultRadius: 10,
    cardRadius: 12,
    cardElevation: 0,
    bottomSheetRadius: 28,
    filledButtonRadius: 12,
    outlinedButtonRadius: 12,
    outlinedButtonBorderWidth: 1.2,
    navigationBarHeight: 72,
    navigationBarIndicatorRadius: 18,
    navigationBarMutedUnselectedIcon: true,
    navigationBarMutedUnselectedLabel: true,
  );

  static ThemeData _polish(
    ThemeData theme, {
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = theme.colorScheme.copyWith(
      brightness: brightness,
      primary: isDark ? darkPrimary : primary,
      onPrimary: isDark ? const Color(0xFF293300) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF3D4A08) : const Color(0xFFE8EFC8),
      onPrimaryContainer:
          isDark ? const Color(0xFFEFF6C8) : const Color(0xFF2B3308),
      secondary: isDark ? const Color(0xFFD9C48F) : const Color(0xFF806B2C),
      surface: isDark ? darkBackground : lightBackground,
      surfaceContainerLowest: isDark ? const Color(0xFF10120C) : Colors.white,
      surfaceContainerLow: isDark ? darkSurface : const Color(0xFFFFFCF4),
      surfaceContainer:
          isDark ? const Color(0xFF25271E) : const Color(0xFFFFFBF0),
      surfaceContainerHighest:
          isDark ? const Color(0xFF2D3024) : const Color(0xFFF1F0E5),
      onSurface: isDark ? darkText : lightText,
      onSurfaceVariant: isDark ? darkMutedText : lightMutedText,
      outlineVariant: isDark ? darkDivider : lightDivider,
    );
    final textTheme = theme.textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return theme.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          height: 1.8,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: colorScheme.surface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: theme.cardTheme.copyWith(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        iconColor: colorScheme.primary,
      ),
      dividerTheme: theme.dividerTheme.copyWith(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
