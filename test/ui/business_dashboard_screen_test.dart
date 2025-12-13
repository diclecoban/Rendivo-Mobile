import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rendivo_mobile/models/app_models.dart';
import 'package:rendivo_mobile/screens/business_dashboard_screen.dart';
import 'package:rendivo_mobile/services/backend_service.dart';
import 'package:rendivo_mobile/services/session_service.dart';

void main() {
  tearDown(() {
    SessionService.instance.clear();
    BackendService.overrideForTesting(null);
  });

  testWidgets('blocks non-owners from viewing dashboard', (tester) async {
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
        home: BusinessDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Business dashboard is available for business owners only.'),
      findsOneWidget,
    );
  });

  testWidgets('renders business metrics and lists', (tester) async {
    SessionService.instance
      ..setUser(
        const AuthUser(
          id: '1',
          email: 'owner@example.com',
          fullName: 'Owner User',
          role: 'business_owner',
        ),
      )
      ..setToken('token');

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/businesses/me') {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'businessName': 'Glow Studio',
              'businessType': 'Salon',
              'phone': '123456',
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
        home: BusinessDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Glow Studio'), findsWidgets);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });
}
