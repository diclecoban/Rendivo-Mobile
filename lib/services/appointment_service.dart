import '../models/app_models.dart';
import 'backend_service.dart';

class AppointmentService {
  AppointmentService._();

  static final BackendService _backend = BackendService.instance;

  static Future<String> createAppointment({
    required Business business,
    required AuthUser customer,
    required List<ServiceItem> services,
    required DateTime startAt,
    required DateTime endAt,
    StaffMember? staff,
    String? notes,
  }) async {
    return _backend.createAppointment(
      businessId: business.id,
      serviceIds: services.map((s) => s.id).toList(),
      startAt: startAt,
      endAt: endAt,
      staffId: staff?.id,
      notes: notes,
    );
  }
}
