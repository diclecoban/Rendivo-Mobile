import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Helper: create user and write users collection
  static Future<UserCredential> _createUserAndProfile({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);

    final uid = cred.user?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        ...profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
  }

  static Future<UserCredential> registerCustomer({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final fullName = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    return await _createUserAndProfile(
      email: email,
      password: password,
      profileData: {
        'firstName': firstName,
        'lastName': lastName ?? '',
        'fullName': fullName,
        'phone': phone ?? '',
        'role': 'customer',
      },
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
