import 'package:flutter/material.dart';

import '../journal/today_page.dart';
import 'biometric_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _service = BiometricService();
  bool _authenticating = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    // Trigger the biometric prompt as soon as the gate paints, so the user
    // sees the system fingerprint sheet without needing a second tap. The
    // fingerprint icon stays on screen as a retry target if auth is
    // dismissed or fails.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tap());
  }

  Future<void> _tap() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _hint = null;
    });
    final result = await _service.authenticate();
    if (!mounted) return;
    switch (result) {
      case AuthOutcome.success:
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TodayPage(),
            transitionDuration: Duration.zero,
          ),
        );
        return;
      case AuthOutcome.unavailable:
        setState(() {
          _hint =
              'Set a device lock (PIN, pattern, or biometric) in your phone settings to protect your journal.';
          _authenticating = false;
        });
        return;
      case AuthOutcome.lockedOut:
        setState(() {
          _hint = 'Too many attempts. Try again later.';
          _authenticating = false;
        });
        return;
      case AuthOutcome.failed:
        setState(() => _authenticating = false);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                button: true,
                label: 'Unlock journal',
                child: InkResponse(
                  onTap: _tap,
                  radius: 96,
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Icon(
                      Icons.fingerprint,
                      size: 128,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _authenticating ? 'Authenticating…' : 'Tap to unlock',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.hintColor),
              ),
              if (_hint != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
