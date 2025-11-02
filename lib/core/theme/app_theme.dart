import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const String bodyFont = 'Inter';
  static const String displayFont = 'Poppins';

  static TextTheme createTextTheme(BuildContext context) {
    final double textScale = MediaQuery.of(context).textScaleFactor.clamp(0.85, 1.15);
    
    return TextTheme(
      displayLarge: GoogleFonts.getFont(
        displayFont,
        fontSize: (57 * textScale).clamp(40.0, 65.0),
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: GoogleFonts.getFont(
        displayFont,
        fontSize: (45 * textScale).clamp(35.0, 52.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: GoogleFonts.getFont(
        displayFont,
        fontSize: (36 * textScale).clamp(28.0, 42.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.22,
      ),
      headlineLarge: GoogleFonts.getFont(
        displayFont,
        fontSize: (32 * textScale).clamp(26.0, 38.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.getFont(
        displayFont,
        fontSize: (28 * textScale).clamp(22.0, 34.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: GoogleFonts.getFont(
        displayFont,
        fontSize: (24 * textScale).clamp(20.0, 30.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.33,
      ),
      titleLarge: GoogleFonts.getFont(
        bodyFont,
        fontSize: (22 * textScale).clamp(18.0, 26.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: GoogleFonts.getFont(
        bodyFont,
        fontSize: (16 * textScale).clamp(14.0, 20.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: GoogleFonts.getFont(
        bodyFont,
        fontSize: (14 * textScale).clamp(12.0, 18.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      bodyLarge: GoogleFonts.getFont(
        bodyFont,
        fontSize: (16 * textScale).clamp(14.0, 20.0),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.getFont(
        bodyFont,
        fontSize: (14 * textScale).clamp(12.0, 18.0),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: GoogleFonts.getFont(
        bodyFont,
        fontSize: (12 * textScale).clamp(10.0, 16.0),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      labelLarge: GoogleFonts.getFont(
        bodyFont,
        fontSize: (14 * textScale).clamp(12.0, 18.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: GoogleFonts.getFont(
        bodyFont,
        fontSize: (12 * textScale).clamp(10.0, 16.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: GoogleFonts.getFont(
        bodyFont,
        fontSize: (11 * textScale).clamp(9.0, 15.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }

  static ColorScheme _lightColorScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff745b00),
      surfaceTint: Color(0xff745b00),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffdfb840),
      onPrimaryContainer: Color(0xff5d4900),
      secondary: Color(0xff6d5d2f),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xfff5dea4),
      onSecondaryContainer: Color(0xff726132),
      tertiary: Color(0xff4a670c),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffa5c865),
      onTertiaryContainer: Color(0xff395300),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffff8f1),
      onSurface: Color(0xff1f1b13),
      onSurfaceVariant: Color(0xff4d4635),
      outline: Color(0xff7f7663),
      outlineVariant: Color(0xffd0c5af),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff343027),
      inversePrimary: Color(0xffeac249),
      primaryFixed: Color(0xffffe08b),
      onPrimaryFixed: Color(0xff241a00),
      primaryFixedDim: Color(0xffeac249),
      onPrimaryFixedVariant: Color(0xff584400),
      secondaryFixed: Color(0xfff8e1a7),
      onSecondaryFixed: Color(0xff241a00),
      secondaryFixedDim: Color(0xffdbc58d),
      onSecondaryFixedVariant: Color(0xff544519),
      tertiaryFixed: Color(0xffcbef87),
      onTertiaryFixed: Color(0xff131f00),
      tertiaryFixedDim: Color(0xffafd36e),
      onTertiaryFixedVariant: Color(0xff364e00),
      surfaceDim: Color(0xffe1d9cc),
      surfaceBright: Color(0xfffff8f1),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffbf3e5),
      surfaceContainer: Color(0xfff5eddf),
      surfaceContainerHigh: Color(0xfff0e7da),
      surfaceContainerHighest: Color(0xffeae1d4),
    );
  }

  static ColorScheme _darkColorScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfffdd459),
      surfaceTint: Color(0xffeac249),
      onPrimary: Color(0xff3d2f00),
      primaryContainer: Color(0xffdfb840),
      onPrimaryContainer: Color(0xff5d4900),
      secondary: Color(0xffdbc58d),
      onSecondary: Color(0xff3c2f05),
      secondaryContainer: Color(0xff544519),
      onSecondaryContainer: Color(0xffc8b37d),
      tertiary: Color(0xffc0e47e),
      onTertiary: Color(0xff243600),
      tertiaryContainer: Color(0xffa5c865),
      onTertiaryContainer: Color(0xff395300),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff16130b),
      onSurface: Color(0xffeae1d4),
      onSurfaceVariant: Color(0xffd0c5af),
      outline: Color(0xff99907c),
      outlineVariant: Color(0xff4d4635),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffeae1d4),
      inversePrimary: Color(0xff745b00),
      primaryFixed: Color(0xffffe08b),
      onPrimaryFixed: Color(0xff241a00),
      primaryFixedDim: Color(0xffeac249),
      onPrimaryFixedVariant: Color(0xff584400),
      secondaryFixed: Color(0xfff8e1a7),
      onSecondaryFixed: Color(0xff241a00),
      secondaryFixedDim: Color(0xffdbc58d),
      onSecondaryFixedVariant: Color(0xff544519),
      tertiaryFixed: Color(0xffcbef87),
      onTertiaryFixed: Color(0xff131f00),
      tertiaryFixedDim: Color(0xffafd36e),
      onTertiaryFixedVariant: Color(0xff364e00),
      surfaceDim: Color(0xff16130b),
      surfaceBright: Color(0xff3d392f),
      surfaceContainerLowest: Color(0xff110e07),
      surfaceContainerLow: Color(0xff1f1b13),
      surfaceContainer: Color(0xff231f17),
      surfaceContainerHigh: Color(0xff2d2a21),
      surfaceContainerHighest: Color(0xff38342b),
    );
  }

  static ThemeData lightTheme(BuildContext context) {
    final textTheme = createTextTheme(context);
    final colorScheme = _lightColorScheme();
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData darkTheme(BuildContext context) {
    final textTheme = createTextTheme(context);
    final colorScheme = _darkColorScheme();
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
