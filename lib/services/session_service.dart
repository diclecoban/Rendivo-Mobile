import '../models/app_models.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  AuthUser? _currentUser;
  String? _authToken;

  AuthUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.id;
  String? get currentRole => _currentUser?.role;
  String? get currentEmail => _currentUser?.email;
  String? get currentName => _currentUser?.fullName;
  String? get authToken => _authToken;

  void setUser(AuthUser user) => _currentUser = user;
  void setToken(String? token) => _authToken = token;

  void clear() {
    _currentUser = null;
    _authToken = null;
  }
}
