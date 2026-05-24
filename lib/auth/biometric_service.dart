import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

enum AuthOutcome { success, failed, unavailable, lockedOut }

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<AuthOutcome> authenticate() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return AuthOutcome.unavailable;

      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your journal',
        options: const AuthenticationOptions(
          // biometricOnly=false → if biometrics fail/unavailable, fall back
          // to device PIN/pattern/passcode. This satisfies the "Device
          // PIN/passcode fallback" requirement.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return ok ? AuthOutcome.success : AuthOutcome.failed;
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notAvailable:
        case auth_error.notEnrolled:
        case auth_error.passcodeNotSet:
          return AuthOutcome.unavailable;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return AuthOutcome.lockedOut;
        default:
          return AuthOutcome.failed;
      }
    }
  }
}
