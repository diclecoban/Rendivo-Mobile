import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessService {
  BusinessService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<DocumentSnapshot<Map<String, dynamic>>?> getBusinessById(String businessId) async {
    final q = await _firestore.collection('businesses').where('businessId', isEqualTo: businessId).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
  }

  // Generate a short unique Business ID (uppercase alnum). Ensures uniqueness by checking 'businesses' collection.
  static Future<String> _generateUniqueBusinessId({int length = 8}) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();

    String generate() => List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();

    for (int attempt = 0; attempt < 10; attempt++) {
      final candidate = generate();
      final q = await _firestore.collection('businesses').where('businessId', isEqualTo: candidate).limit(1).get();
      if (q.docs.isEmpty) return candidate;
    }

    // fallback with timestamp
    return 'BIZ${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  // Create a business owner account and business record in a single flow
  static Future<Map<String, dynamic>> createBusiness({
    required String ownerFullName,
    required String email,
    required String password,
    required Map<String, dynamic> businessData,
  }) async {
    // 1) Create auth user
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);

    final uid = cred.user!.uid;

    // write user profile
    await _firestore.collection('users').doc(uid).set({
      'fullName': ownerFullName,
      'email': email,
      'role': 'business_owner',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) Create business record
    final businessId = await _generateUniqueBusinessId();
    final docRef = await _firestore.collection('businesses').add({
      'ownerId': uid,
      'businessName': businessData['businessName'] ?? '',
      'businessType': businessData['businessType'] ?? '',
      'description': businessData['description'] ?? '',
      'address': businessData['address'] ?? {},
      'phone': businessData['phone'] ?? '',
      'email': businessData['email'] ?? '',
  'logo': businessData['logo'],
      'businessId': businessId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3) Optionally add owner as staff member in a 'staff_members' collection
    await _firestore.collection('staff_members').add({
      'userId': uid,
      'businessDocId': docRef.id,
      'businessId': businessId,
      'position': 'owner',
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'uid': uid,
      'businessDocId': docRef.id,
      'businessId': businessId,
    };
  }

  // Register staff: validate businessId exists, then create user and staff_members entry
  static Future<Map<String, dynamic>> addStaff({
    required String fullName,
    required String email,
    required String password,
    required String businessId,
    String position = 'staff',
  }) async {
    // find business by businessId
    final q = await _firestore.collection('businesses').where('businessId', isEqualTo: businessId).limit(1).get();
    if (q.docs.isEmpty) throw Exception('Business ID not found');

    final businessDoc = q.docs.first;

    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);

    final uid = cred.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'fullName': fullName,
      'email': email,
      'role': 'staff',
      'businessId': businessId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('staff_members').add({
      'userId': uid,
      'businessDocId': businessDoc.id,
      'businessId': businessId,
      'position': position,
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'uid': uid,
      'businessDocId': businessDoc.id,
      'businessId': businessId,
    };
  }

  // Add an existing user to staff_members (useful if user already exists)
  static Future<void> addExistingUserToBusiness({
    required String userId,
    required String businessDocId,
    required String businessId,
    String position = 'staff',
  }) async {
    await _firestore.collection('staff_members').add({
      'userId': userId,
      'businessDocId': businessDocId,
      'businessId': businessId,
      'position': position,
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
