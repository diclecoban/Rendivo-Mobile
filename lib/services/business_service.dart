import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class BusinessService {
  BusinessService._();

  static Future<DocumentSnapshot<Map<String, dynamic>>?> getBusinessById(String businessId) async {
    return FirebaseService.getBusinessByBusinessId(businessId);
  }

  static Future<Map<String, dynamic>> createBusiness({
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

  static Future<Map<String, dynamic>> addStaff({
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

  static Future<void> addExistingUserToBusiness({
    required String userId,
    required String businessDocId,
    required String businessId,
    String position = 'staff',
  }) async {
    return FirebaseService.addStaffToBusiness(
      userId: userId,
      businessDocId: businessDocId,
      businessId: businessId,
      position: position,
    );
  }
}
