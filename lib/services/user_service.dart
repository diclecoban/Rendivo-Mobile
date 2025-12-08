import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  static Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  static Future<String?> getCurrentRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await getProfile(user.uid);
    return doc.data()?['role'] as String?;
  }
}
