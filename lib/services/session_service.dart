import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  SharedPreferences? _prefs;
  AuthUser? _currentUser;
  String? _authToken;
  void Function()? _onSessionExpired;

  AuthUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.id;
  String? get currentRole => _currentUser?.role;
  String? get currentEmail => _currentUser?.email;
  String? get currentName => _currentUser?.fullName;
  String? get authToken => _authToken;
  bool get hasValidSession =>
      _currentUser != null &&
      _authToken != null &&
      _authToken!.isNotEmpty &&
      !isTokenExpired(_authToken);

  void registerSessionExpiredHandler(void Function() handler) {
    _onSessionExpired = handler;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final token = _prefs?.getString(_tokenKey);
    final rawUser = _prefs?.getString(_userKey);
    AuthUser? user;
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map<String, dynamic>) {
          user = AuthUser.fromJson(decoded, token: token);
        }
      } catch (_) {
        // Ignore malformed stored session data.
      }
    }
    _currentUser = user;
    _authToken = token;
    if (isTokenExpired(_authToken)) {
      _currentUser = null;
      _authToken = null;
      await _clearPersisted();
    }
  }

  void setUser(AuthUser user) {
    _currentUser = user;
    unawaited(_persistUser());
  }

  void setToken(String? token) {
    _authToken = token;
    unawaited(_persistToken());
  }

  void clear() {
    _currentUser = null;
    _authToken = null;
    unawaited(_clearPersisted());
  }

  void handleTokenExpired() {
    clear();
    _onSessionExpired?.call();
  }

  bool isTokenExpired([String? token]) {
    final value = token ?? _authToken;
    if (value == null || value.isEmpty) return true;
    final parts = value.split('.');
    if (parts.length != 3) return true;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        final expRaw = payload['exp'];
        final exp = expRaw is int
            ? expRaw
            : expRaw is String
                ? int.tryParse(expRaw)
                : null;
        if (exp == null) return true;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return exp <= now;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<void> _persistUser() async {
    _prefs ??= await SharedPreferences.getInstance();
    final user = _currentUser;
    if (user == null) {
      await _prefs?.remove(_userKey);
      return;
    }
    await _prefs?.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _persistToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    final token = _authToken;
    if (token == null || token.isEmpty) {
      await _prefs?.remove(_tokenKey);
      return;
    }
    await _prefs?.setString(_tokenKey, token);
  }

  Future<void> _clearPersisted() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(_userKey);
    await _prefs?.remove(_tokenKey);
  }
}
