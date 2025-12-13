import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rendivo_mobile/screens/customer_signup_screen.dart';
import 'package:rendivo_mobile/screens/owner/owner_signup_step1_screen.dart';
import 'package:rendivo_mobile/screens/login_screen.dart';
import 'package:rendivo_mobile/screens/signup_role_screen.dart';
import 'package:rendivo_mobile/screens/staff_signup_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Log In'));
      await tester.pump();

      expect(
        find.text('Please enter your email address.'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter your password.'),
        findsOneWidget,
      );
    });
  });

  group('CustomerSignUpScreen', () {
    testWidgets('requires mandatory fields before submission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerSignUpScreen(),
          ),
        ),
      );

      final createButton = find.text('Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter your First name.'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter your email address.'),
        findsOneWidget,
      );
    });
  });

  group('SignupRoleScreen', () {
    testWidgets('navigates to CustomerSignUpScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupRoleScreen(),
        ),
      );

      await tester.tap(find.text("I'm a Customer"));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerSignUpScreen), findsOneWidget);
    });

    testWidgets('navigates to StaffSignUpScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupRoleScreen(),
        ),
      );

      await tester.tap(find.text("I'm a Staff Member"));
      await tester.pumpAndSettle();

      expect(find.byType(StaffSignUpScreen), findsOneWidget);
    });

    testWidgets('navigates to BusinessOwnerSignUpScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupRoleScreen(),
        ),
      );

      await tester.tap(find.text("I'm a Business Owner"));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessOwnerSignUpScreen), findsOneWidget);
    });
  });

  group('BusinessOwnerSignUpScreen', () {
    testWidgets('requires terms checkbox before enabling next step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BusinessOwnerSignUpScreen(),
        ),
      );

      final nextButtonFinder = find.widgetWithText(ElevatedButton, 'Next Step');
      ElevatedButton button = tester.widget(nextButtonFinder);
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      button = tester.widget(nextButtonFinder);
      expect(button.onPressed, isNotNull);
    });
  });

  group('StaffSignUpScreen', () {
    testWidgets('shows informational snackbar when submitting form', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StaffSignUpScreen(),
        ),
      );

      final button = find.text('Create Account & Join Business');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(); // start animation
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text(
          'Staff onboarding will be available after the new backend is connected.',
        ),
        findsOneWidget,
      );
    });
  });
}
