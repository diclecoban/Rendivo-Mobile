import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();
  static final auth = FirebaseAuth.instance;
  static final firestore = FirebaseFirestore.instance;

  // --------------------------- Auth helpers ---------------------------
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user?.uid;
    if (uid != null) {
      await firestore.collection('users').doc(uid).set({
        'email': email,
        ...profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await auth.signOut();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String uid) async {
    return await firestore.collection('users').doc(uid).get();
  }

  static Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(uid).update(data);
  }

  // --------------------------- Business & Staff flows ---------------------------

  // Generate a short unique Business ID (uppercase alnum). Ensures uniqueness by checking 'businesses' collection.
  static Future<String> _generateUniqueBusinessId({int length = 8}) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();

    String generate() => List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();

    for (int attempt = 0; attempt < 10; attempt++) {
      final candidate = generate();
      final q = await firestore.collection('businesses').where('businessId', isEqualTo: candidate).limit(1).get();
      if (q.docs.isEmpty) return candidate;
    }

    // fallback with timestamp
    return 'BIZ${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  // Create a business owner account and business record in a single flow
  static Future<Map<String, dynamic>> registerBusiness({
    required String ownerFullName,
    required String email,
    required String password,
    required Map<String, dynamic> businessData,
  }) async {
    // 1) Create auth user
    final cred = await signUpWithEmail(
      email: email,
      password: password,
      profileData: {
        'fullName': ownerFullName,
        'role': 'business_owner',
      },
    );

    final uid = cred.user!.uid;

    // 2) Create business record
    final businessId = await _generateUniqueBusinessId();
    final docRef = await firestore.collection('businesses').add({
      'ownerId': uid,
      'businessName': businessData['businessName'] ?? '',
      'businessType': businessData['businessType'] ?? '',
      'description': businessData['description'] ?? '',
      'address': businessData['address'] ?? {},
      'phone': businessData['phone'] ?? '',
      'email': businessData['email'] ?? '',
      'logo': businessData['logo'] ?? null,
      'businessId': businessId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3) Optionally add owner as staff member in a 'staff_members' collection
    await firestore.collection('staff_members').add({
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
  static Future<Map<String, dynamic>> registerStaff({
    required String fullName,
    required String email,
    required String password,
    required String businessId,
    String position = 'staff',
  }) async {
    // find business by businessId
    final q = await firestore.collection('businesses').where('businessId', isEqualTo: businessId).limit(1).get();
    if (q.docs.isEmpty) throw Exception('Business ID not found');

    final businessDoc = q.docs.first;

    final cred = await signUpWithEmail(
      email: email,
      password: password,
      profileData: {
        'fullName': fullName,
        'role': 'staff',
        'businessId': businessId,
      },
    );

    final uid = cred.user!.uid;

    await firestore.collection('staff_members').add({
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

  // Register customer: simple user creation with role customer
  static Future<UserCredential> registerCustomer({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final fullName = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    return await signUpWithEmail(
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

  // Lookup business by businessId
  static Future<DocumentSnapshot<Map<String, dynamic>>?> getBusinessByBusinessId(String businessId) async {
    final q = await firestore.collection('businesses').where('businessId', isEqualTo: businessId).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
  }

  // Add an existing user to staff_members (useful if user already exists)
  static Future<void> addStaffToBusiness({
    required String userId,
    required String businessDocId,
    required String businessId,
    String position = 'staff',
  }) async {
    await firestore.collection('staff_members').add({
      'userId': userId,
      'businessDocId': businessDocId,
      'businessId': businessId,
      'position': position,
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Convenience: get current user's role from Firestore doc
  static Future<String?> getCurrentUserRole() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final doc = await getProfile(user.uid);
    return doc.data()?['role'] as String?;
  }
}

