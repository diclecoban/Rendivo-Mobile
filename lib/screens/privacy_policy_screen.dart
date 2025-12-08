import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SectionTitle('1. Data We Collect'),
              _SectionBody(
                'We collect the profile details you share (name, email, phone) plus booking metadata '
                'such as services selected and appointment times. We do not store payment card numbers.',
              ),
              _SectionTitle('2. Why We Collect Data'),
              _SectionBody(
                'Data is used to create bookings, send confirmations, and help businesses prepare for upcoming appointments.',
              ),
              _SectionTitle('3. Sharing'),
              _SectionBody(
                'Information is shared only with the business you book and trusted providers (like authentication or analytics tools) '
                'that help us deliver the service.',
              ),
              _SectionTitle('4. Your Choices'),
              _SectionBody(
                'You may request data removal or export by contacting support@rendivo.com. '
                'Within the app you can update your profile details at any time.',
              ),
              _SectionTitle('5. Security'),
              _SectionBody(
                'We rely on Firebase security standards and follow best practices to keep your information safe.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: primaryPink,
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;

  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
    );
  }
}
