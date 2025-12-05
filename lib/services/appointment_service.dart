import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class AppointmentService {
  AppointmentService._();

  // Create a simple appointment for a business
  static Future<DocumentReference> createAppointment({
    required String businessDocId,
    required Map<String, dynamic> appointmentData,
  }) async {
    // store under businesses/{businessDocId}/appointments
    final ref = FirebaseService.firestore
        .collection('businesses')
        .doc(businessDocId)
        .collection('appointments')
        .doc();

    await ref.set({
      ...appointmentData,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref;
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> listAppointmentsForBusiness(String businessDocId) async {
    return FirebaseService.firestore
        .collection('businesses')
        .doc(businessDocId)
        .collection('appointments')
        .orderBy('startAt', descending: false)
        .get();
  }
}
