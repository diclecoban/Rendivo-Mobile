import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class AuthService {
  AuthService._();

  static Future<UserCredential> signIn(String email, String password) async {
    return FirebaseService.signInWithEmail(email: email, password: password);
  }

  static Future<UserCredential> registerCustomer({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    return FirebaseService.registerCustomer(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      phone: phone,
    );
  }

  static Future<Map<String, dynamic>> registerBusiness({
    required String ownerFullName,
    required String email,
    required String password,
    required Map<String, dynamic> businessData,
  }) async {
    return FirebaseService.registerBusiness(
      ownerFullName: ownerFullName,
      email: email,
      password: password,
      businessData: businessData,
    );
  }

  static Future<Map<String, dynamic>> registerStaff({
    required String fullName,
    required String email,
    required String password,
    required String businessId,
    String position = 'staff',
  }) async {
    return FirebaseService.registerStaff(
      fullName: fullName,
      email: email,
      password: password,
      businessId: businessId,
      position: position,
    );
  }

  static Future<void> signOut() async => FirebaseService.signOut();
}
