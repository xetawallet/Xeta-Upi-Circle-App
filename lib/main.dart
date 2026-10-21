import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

const _brandGreen = Color(0xFF16423D);
const _brandAmber = Color(0xFFE29A45);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    XetaUpiCircleApp(
      showOnboarding: prefs.getBool('onboarding_completed') != true,
      initialDarkMode: prefs.getBool('dark_mode') ?? true,
    ),
  );
}

class XetaUpiCircleApp extends StatefulWidget {
  const XetaUpiCircleApp({
    super.key,
    required this.showOnboarding,
    this.initialDarkMode = true,
  });

  final bool showOnboarding;
  final bool initialDarkMode;

  @override
  State<XetaUpiCircleApp> createState() => _XetaUpiCircleAppState();
}

class _XetaUpiCircleAppState extends State<XetaUpiCircleApp> {
  late bool _darkMode = widget.initialDarkMode;
  int _themePreferenceRevision = 0;
  Future<void> _themePreferenceWrite = Future<void>.value();

  Future<void> _setDarkMode(bool value) {
    if (!mounted || _darkMode == value) return Future<void>.value();
    setState(() => _darkMode = value);
    final revision = ++_themePreferenceRevision;
    _themePreferenceWrite = _themePreferenceWrite.then((_) async {
      if (revision != _themePreferenceRevision) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (revision == _themePreferenceRevision) {
          await prefs.setBool('dark_mode', value);
        }
      } catch (_) {
        // Keep the current in-memory theme even if persistence is unavailable.
      }
    });
    return _themePreferenceWrite;
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandGreen,
      brightness: brightness,
      primary: dark ? const Color(0xFF8AD2BF) : _brandGreen,
      onPrimary: dark ? const Color(0xFF06372F) : Colors.white,
      secondary: dark ? const Color(0xFFF3B96D) : _brandAmber,
      surface: dark ? const Color(0xFF111C1B) : const Color(0xFFFBF8F2),
      onSurface: dark ? const Color(0xFFE4ECE9) : const Color(0xFF19302E),
      onSurfaceVariant: dark
          ? const Color(0xFFB0C2BD)
          : const Color(0xFF5A706C),
      outline: dark ? const Color(0xFF52635F) : const Color(0xFFD7CEC1),
      surfaceContainerLow: dark
          ? const Color(0xFF182523)
          : const Color(0xFFFFFFFF),
      surfaceContainer: dark
          ? const Color(0xFF202E2C)
          : const Color(0xFFF5EFE5),
      surfaceContainerHighest: dark
          ? const Color(0xFF2B3A37)
          : const Color(0xFFEFE8DE),
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF111C1B)
          : const Color(0xFFF5EFE5),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xeta UPI Circle App',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.showOnboarding
          ? OnboardingScreen(
              darkModeEnabled: _darkMode,
              onDarkModeChanged: _setDarkMode,
            )
          : HomeScreen(
              darkModeEnabled: _darkMode,
              onDarkModeChanged: _setDarkMode,
            ),
    );
  }
}
