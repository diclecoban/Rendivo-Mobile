import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class UserService {
  UserService._();

  static Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String uid) async {
    return FirebaseService.getProfile(uid);
  }

  static Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    return FirebaseService.updateProfile(uid, data);
  }

  static Future<String?> getCurrentRole() async {
    return FirebaseService.getCurrentUserRole();
  }
}
