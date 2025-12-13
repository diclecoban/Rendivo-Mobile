import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendivo_mobile/models/app_models.dart';
import 'package:rendivo_mobile/screens/customer_dashboard_screen.dart';
import 'package:rendivo_mobile/services/backend_service.dart';
import 'package:rendivo_mobile/services/session_service.dart';

void main() {
  setUp(() {
    SessionService.instance
      ..setUser(
        const AuthUser(
          id: '1',
          email: 'user@example.com',
          fullName: 'Test User',
          role: 'customer',
        ),
      )
      ..setToken('token');
  });

  tearDown(() {
    SessionService.instance.clear();
    BackendService.overrideForTesting(null);
  });

  testWidgets('renders stats and next appointment from dashboard API', (tester) async {
    final mockClient = MockClient((request) async {
      switch (request.url.path) {
        case '/api/customer/dashboard':
          return http.Response(
            jsonEncode({
              'upcomingCount': 2,
              'totalBookings': 8,
              'nextAppointment': {
                'title': 'Glow Facial',
                'startAt': '2025-03-10T14:00:00Z',
                'endAt': '2025-03-10T15:00:00Z',
              },
            }),
            200,
          );

        case '/api/appointments/me':
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'businessId': 10,
                'businessName': 'Glow Spa',
                'customerId': 1,
                'customerName': 'Test User',
                'customerEmail': 'user@example.com',
                'services': [],
                'totalPrice': 120,
                'totalDuration': 60,
                'status': 'confirmed',
                'appointmentDate': '2025-03-10',
                'startTime': '14:00:00',
                'endTime': '15:00:00',
              },
            ]),
            200,
          );
        default:
          return http.Response('Not Found', 404);
      }
    });

    final backend = BackendService.test(
      client: mockClient,
      baseUrl: 'http://localhost:1234/api',
    );

    BackendService.overrideForTesting(backend);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    expect(find.text('Glow Facial'), findsOneWidget);
    expect(find.textContaining('View all'), findsOneWidget);
  });
}
