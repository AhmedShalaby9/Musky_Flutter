import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef LoginCredentials = ({String email, String password});

/// Persists the last successful login in the OS keychain / credential store.
/// Every call swallows storage errors so login never depends on it.
abstract class SavedLogin {
  Future<LoginCredentials?> read();
  Future<void> write(String email, String password);
  Future<void> clear();
}

class SecureSavedLogin implements SavedLogin {
  const SecureSavedLogin();

  static const _storage = FlutterSecureStorage(
    // The legacy macOS keychain needs no keychain-access-groups entitlement,
    // which an ad-hoc signed sandboxed build does not have.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _emailKey = 'login_email';
  static const _passwordKey = 'login_password';

  @override
  Future<LoginCredentials?> read() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String email, String password) async {
    try {
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _passwordKey, value: password);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {}
  }
}
