import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendivo_mobile/models/app_models.dart';
import 'package:rendivo_mobile/screens/staff_dashboard_screen.dart';
import 'package:rendivo_mobile/services/backend_service.dart';
import 'package:rendivo_mobile/services/session_service.dart';

void main() {
  tearDown(() {
    SessionService.instance.clear();
    BackendService.overrideForTesting(null);
  });

  testWidgets('shows error when not staff', (tester) async {
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

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Staff dashboard is available for staff accounts only.'), findsOneWidget);
  });

  testWidgets('renders staff bookings list from backend', (tester) async {
    SessionService.instance
      ..setUser(
        const AuthUser(
          id: '1',
          email: 'staff@example.com',
          fullName: 'Staff Member',
          role: 'staff',
        ),
      )
      ..setToken('token');

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/staff/appointments') {
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
              'status': 'confirmed',
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
      }
      return http.Response('Not Found', 404);
    });

    final backend = BackendService.test(
      client: mockClient,
      baseUrl: 'http://localhost:1234/api',
    );
    BackendService.overrideForTesting(backend);

    await tester.pumpWidget(
      const MaterialApp(
        home: StaffDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cut'), findsOneWidget);
    expect(find.textContaining('Alice'), findsOneWidget);
  });
}
