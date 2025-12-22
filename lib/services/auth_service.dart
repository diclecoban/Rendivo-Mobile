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
    required String fullName,
    required String email,
    required String password,
    required String businessId,
  }) async {
    return _backend.registerStaff(
      fullName: fullName,
      email: email,
      password: password,
      businessId: businessId,
    );
  }

  static void signOut() => _session.clear();
}
