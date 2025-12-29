import '../models/app_models.dart';
import 'backend_service.dart';
import 'session_service.dart';

class AuthService {
  AuthService._();

  static final BackendService _backend = BackendService.instance;
  static final SessionService _session = SessionService.instance;

  static Future<AuthUser> signIn(String email, String password) async {
    return _backend.login(email, password);
  }

  static Future<AuthUser> registerCustomer({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    return _backend.registerCustomer(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      phone: phone,
    );
  }

  static Future<AuthUser> registerStaff({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String businessId,
  }) async {
    return _backend.registerStaff(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      phone: phone,
      businessId: businessId,
    );
  }

  static Future<void> requestPasswordReset(String email) async {
    await _backend.requestPasswordReset(email);
  }

  static Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) async {
    await _backend.confirmPasswordReset(
      email: email,
      code: code,
      password: password,
    );
  }

  static Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _backend.verifyEmail(email: email, code: code);
  }

  static void signOut() => _session.clear();
}
