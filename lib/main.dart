import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const JournalApp());
}

class JournalApp extends StatefulWidget {
  const JournalApp({super.key});

  @override
  State<JournalApp> createState() => _JournalAppState();
}

class _JournalAppState extends State<JournalApp> with WidgetsBindingObserver {
  // Re-lock the app if it has been backgrounded for this long.
  static const _relockAfter = Duration(minutes: 5);

  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[lifecycle] $state (backgroundedAt=$_backgroundedAt)');
    if (state != AppLifecycleState.resumed) {
      // Treat any non-resumed state (paused / inactive / hidden / detached)
      // as the start of a background interval. ??= so multiple non-resumed
      // transitions during one backgrounding don't reset the clock.
      _backgroundedAt ??= DateTime.now();
    } else if (_backgroundedAt != null) {
      final elapsed = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (elapsed >= _relockAfter) {
        // Re-lock: clear the stack and return to AuthGate. Defer to the
        // next frame so the navigator is guaranteed to be attached and
        // ready after the resume transition.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const AuthGate(),
              transitionDuration: Duration.zero,
            ),
            (route) => false,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5A80),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D5A80),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Journal',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          surfaceTintColor: lightScheme.surface,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          surfaceTintColor: darkScheme.surface,
          centerTitle: false,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
