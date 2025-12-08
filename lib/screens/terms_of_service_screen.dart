import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Terms of Service',
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
              _SectionTitle('1. Overview'),
              _SectionBody(
                'By creating an account you agree to abide by our platform rules. '
                'Rendivo provides appointment scheduling tools and does not assume liability '
                'for services rendered by individual businesses.',
              ),
              _SectionTitle('2. Use of Service'),
              _SectionBody(
                'You are responsible for the accuracy of the information you provide. '
                'Do not misuse the platform, attempt unauthorized access, or interfere with other users.',
              ),
              _SectionTitle('3. Payments & Cancellations'),
              _SectionBody(
                'Each business defines its own pricing and cancellation policies. '
                'Always review the business rules before confirming an appointment.',
              ),
              _SectionTitle('4. Data'),
              _SectionBody(
                'We store basic profile information to power your booking experience. '
                'Details about how we store and protect data are outlined in the Privacy Policy.',
              ),
              _SectionTitle('5. Updates'),
              _SectionBody(
                'These terms may change as the product evolves. We will notify you about material updates.',
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
