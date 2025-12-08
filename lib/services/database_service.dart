import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// DatabaseService
/// A thin consolidated service that uses Firebase Auth + Firestore directly.
/// Use this when you don't want a separate backend and prefer client -> Firebase.
class DatabaseService {
  DatabaseService._();

  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Optional: ensure Firebase is initialized (main.dart usually does this).
  static Future<void> ensureInitialized() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // already initialized or failed; ignore here — caller can handle errors
    }
  }

  // --------------------------- Auth ---------------------------
  static Future<UserCredential> signIn({required String email, required String password}) async {
    return await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await auth.signOut();
  }

  // Helper to create user and profile doc
  static Future<UserCredential> _createUserWithProfile({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
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

  static Future<UserCredential> registerCustomer({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final fullName = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    return await _createUserWithProfile(
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

  // --------------------------- Business & Staff ---------------------------
  static Future<String> _generateUniqueBusinessId({int length = 8}) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();

    String generate() => List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();

    for (int attempt = 0; attempt < 10; attempt++) {
      final candidate = generate();
      final q = await firestore.collection('businesses').where('businessId', isEqualTo: candidate).limit(1).get();
      if (q.docs.isEmpty) return candidate;
    }

    return 'BIZ${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  }

  /// Create a business owner account + business document + staff_members entry.
  static Future<Map<String, dynamic>> createBusiness({
    required String ownerFullName,
    required String email,
    required String password,
    required Map<String, dynamic> businessData,
  }) async {
    final cred = await _createUserWithProfile(
      email: email,
      password: password,
      profileData: {
        'fullName': ownerFullName,
        'role': 'business_owner',
      },
    );

    final uid = cred.user!.uid;

    final businessId = await _generateUniqueBusinessId();
    final docRef = await firestore.collection('businesses').add({
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

  /// Register staff (creates auth user and staff_members entry)
  static Future<Map<String, dynamic>> addStaff({
    required String fullName,
    required String email,
    required String password,
    required String businessId,
    String position = 'staff',
  }) async {
    final q = await firestore.collection('businesses').where('businessId', isEqualTo: businessId).limit(1).get();
    if (q.docs.isEmpty) throw Exception('Business ID not found');
    final businessDoc = q.docs.first;

    final cred = await _createUserWithProfile(
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

  static Future<void> addExistingUserToBusiness({
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

  static Future<DocumentSnapshot<Map<String, dynamic>>?> getBusinessById(String businessId) async {
    final q = await firestore.collection('businesses').where('businessId', isEqualTo: businessId).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
  }

  // --------------------------- Appointments ---------------------------
  static Future<DocumentReference> createAppointment({
    required String businessDocId,
    required Map<String, dynamic> appointmentData,
  }) async {
    final ref = firestore.collection('businesses').doc(businessDocId).collection('appointments').doc();
    await ref.set({
      ...appointmentData,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref;
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> listAppointmentsForBusiness(String businessDocId) async {
    return await firestore.collection('businesses').doc(businessDocId).collection('appointments').orderBy('startAt', descending: false).get();
  }

  // --------------------------- Profile ---------------------------
  static Future<DocumentSnapshot<Map<String, dynamic>>> getProfile(String uid) async {
    return await firestore.collection('users').doc(uid).get();
  }

  static Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(uid).update(data);
  }

  static Future<String?> getCurrentUserRole() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final doc = await getProfile(user.uid);
    return doc.data()?['role'] as String?;
  }
}
