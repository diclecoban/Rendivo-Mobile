import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendivo_mobile/models/app_models.dart';
import 'package:rendivo_mobile/services/appointment_service.dart';
import 'package:rendivo_mobile/services/backend_service.dart';

void main() {
  tearDown(() {
    AppointmentService.resetBackend();
    BackendService.overrideForTesting(null);
  });

  test('createAppointment sends selected services and returns id', () async {
    late Map<String, dynamic> capturedBody;

    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/appointments');
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

      return http.Response(
        jsonEncode({
          'appointmentId': 99,
          'totalPrice': 120,
          'totalDuration': 90,
          'status': 'pending',
        }),
        201,
      );
    });

    final backend = BackendService.test(
      client: mockClient,
      baseUrl: 'http://localhost:1234/api',
    );

    AppointmentService.overrideBackend(backend);

    final business = Business(
      id: '7',
      businessName: 'Glow Studio',
      businessType: 'Salon',
      phone: '',
      email: '',
      address: const Address(
        street: '',
        city: '',
        state: '',
        postalCode: '',
      ),
      services: const [],
      staff: const [],
    );

    final customer = const AuthUser(
      id: '1',
      email: 'user@example.com',
      fullName: 'Test User',
      role: 'customer',
    );

    final services = [
      const ServiceItem(
        id: '11',
        name: 'Cut',
        price: 60,
        durationMinutes: 45,
      ),
      const ServiceItem(
        id: '12',
        name: 'Color',
        price: 60,
        durationMinutes: 45,
      ),
    ];

    final startAt = DateTime(2025, 1, 1, 12);
    final endAt = startAt.add(const Duration(minutes: 90));

    final appointmentId = await AppointmentService.createAppointment(
      business: business,
      customer: customer,
      services: services,
      startAt: startAt,
      endAt: endAt,
      staff: null,
      notes: 'Bring coffee',
    );

    expect(appointmentId, '99');
    expect(capturedBody['businessId'], 7);
    expect(capturedBody['serviceIds'], [11, 12]);
    expect(capturedBody['notes'], 'Bring coffee');
    expect(capturedBody['startTime'], '12:00:00');
  });
}
