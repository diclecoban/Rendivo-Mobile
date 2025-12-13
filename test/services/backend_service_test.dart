import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendivo_mobile/models/app_models.dart';
import 'package:rendivo_mobile/services/backend_service.dart';

void main() {
  group('BackendService.fetchBusinessAvailability', () {
    test('parses available slots from backend response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/businesses/42/availability');
        expect(request.url.queryParameters['date'], '2025-01-01');
        expect(request.url.queryParameters['durationMinutes'], '60');

        final body = jsonEncode({
          'date': '2025-01-01',
          'slotMinutes': 30,
          'durationMinutes': 60,
          'slots': [
            {
              'startAt': '2025-01-01T09:00:00Z',
              'endAt': '2025-01-01T10:00:00Z',
            },
            {
              'startAt': '2025-01-01T10:00:00Z',
              'endAt': '2025-01-01T11:00:00Z',
            },
          ],
        });
        return http.Response(body, 200);
      });

      final service = BackendService.test(
        client: mockClient,
        baseUrl: 'http://localhost:1234/api',
      );

      final slots = await service.fetchBusinessAvailability(
        businessId: '42',
        date: DateTime(2025, 1, 1),
        durationMinutes: 60,
      );

      expect(slots, hasLength(2));
      expect(slots.first.startAt.toUtc(), DateTime.utc(2025, 1, 1, 9));
      expect(slots.first.endAt.toUtc(), DateTime.utc(2025, 1, 1, 10));
    });
  });

  group('BackendService.fetchCustomerDashboard', () {
    test('returns stats and next appointment map', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/customer/dashboard');

        return http.Response(
          jsonEncode({
            'upcomingCount': 3,
            'totalBookings': 12,
            'nextAppointment': {
              'title': 'Glow Facial',
              'startAt': '2025-02-01T10:00:00Z',
              'endAt': '2025-02-01T11:00:00Z',
            },
          }),
          200,
        );
      });

      final service = BackendService.test(
        client: mockClient,
        baseUrl: 'http://localhost:1234/api',
      );

      final map = await service.fetchCustomerDashboard();

      expect(map['upcomingCount'], 3);
      expect(map['totalBookings'], 12);
      expect(map['nextAppointment']['title'], 'Glow Facial');
    });
  });

  group('BackendService.fetchStaffAppointments', () {
    test('returns mapped appointments for staff member', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/staff/appointments');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'businessId': 5,
              'businessName': 'Glow Studio',
              'customerId': 10,
              'customerName': 'Alice',
              'customerEmail': 'alice@example.com',
              'appointmentDate': '2025-04-02',
              'startTime': '10:00:00',
              'endTime': '11:00:00',
              'status': 'pending',
              'services': [
                {
                  'id': 11,
                  'name': 'Cut',
                  'price': 50,
                  'duration': 30,
                }
              ],
            }
          ]),
          200,
        );
      });

      final service = BackendService.test(
        client: mockClient,
        baseUrl: 'http://localhost:1234/api',
      );

      final appointments = await service.fetchStaffAppointments();

      expect(appointments, hasLength(1));
      expect(appointments.first.businessName, 'Glow Studio');
      expect(appointments.first.services.first.name, 'Cut');
    });
  });

  group('BackendService.fetchMyBusinesses', () {
    test('returns businesses with services and staff', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/businesses/me');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'businessName': 'Glow Studio',
              'businessType': 'Salon',
              'phone': '123',
              'email': 'owner@glow.com',
              'address': '123 Main',
              'city': 'NYC',
              'state': 'NY',
              'zipCode': '10001',
              'services': [
                {'id': 11, 'name': 'Cut', 'price': 50, 'duration': 30}
              ],
              'staff': [
                {'id': 21, 'name': 'Alice', 'role': 'Stylist'}
              ],
            }
          ]),
          200,
        );
      });

      final service = BackendService.test(
        client: mockClient,
        baseUrl: 'http://localhost:1234/api',
      );

      final businesses = await service.fetchMyBusinesses();
      expect(businesses, hasLength(1));
      expect(businesses.first.businessName, 'Glow Studio');
      expect(businesses.first.services.first.name, 'Cut');
      expect(businesses.first.staff.first.name, 'Alice');
    });
  });
}
