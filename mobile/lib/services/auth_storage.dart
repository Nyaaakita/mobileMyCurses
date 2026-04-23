import "package:flutter_secure_storage/flutter_secure_storage.dart";

class AuthStorage {
  static const _kAccess = "access_token";
  static const _kRefresh = "refresh_token";
  static const _kRole = "role";
  static const _kUserId = "user_id";
  static const _kEmail = "email";
  static const _kName = "name";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    String? userId,
    String? email,
    String? name,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kRole, value: role);
    if (userId != null) await _storage.write(key: _kUserId, value: userId);
    if (email != null) await _storage.write(key: _kEmail, value: email);
    if (name != null) await _storage.write(key: _kName, value: name);
  }

  Future<StoredSession?> readSession() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    final role = await _storage.read(key: _kRole);
    final userId = await _storage.read(key: _kUserId);
    final email = await _storage.read(key: _kEmail);
    final name = await _storage.read(key: _kName);
    if (access == null || access.isEmpty) return null;
    return StoredSession(
      accessToken: access,
      refreshToken: refresh ?? access,
      role: role ?? "student",
      userId: userId,
      email: email,
      name: name,
    );
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    this.userId,
    this.email,
    this.name,
  });

  final String accessToken;
  final String refreshToken;
  final String role;
  final String? userId;
  final String? email;
  final String? name;
}
