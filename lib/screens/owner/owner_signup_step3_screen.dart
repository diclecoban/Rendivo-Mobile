import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/owner_signup.dart';
import '../../services/backend_service.dart';
import '../email_verification_notice_screen.dart';

class BusinessOwnerSignUpStep3Screen extends StatefulWidget {
  const BusinessOwnerSignUpStep3Screen({super.key});

  @override
  State<BusinessOwnerSignUpStep3Screen> createState() =>
      _BusinessOwnerSignUpStep3ScreenState();
}

class _BusinessOwnerSignUpStep3ScreenState
    extends State<BusinessOwnerSignUpStep3Screen> {
  final _model = OwnerSignupModel.instance;
  final _backend = BackendService.instance;

  bool _submitting = false;
  String? _error;

  Future<void> _submit(BuildContext context) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _backend.registerBusinessOwner(_model);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please verify your email.'),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationNoticeScreen(
            email: _model.email.isNotEmpty ? _model.email : null,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName =
        _model.businessName.isNotEmpty ? _model.businessName : 'your business';
    final category =
        _model.businessType.isNotEmpty ? _model.businessType : 'Category TBD';
    final contact = _model.publicEmail.isNotEmpty
        ? _model.publicEmail
        : _model.email;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rendivo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryPink,
                      child: Text(
                        _model.fullName.isNotEmpty
                            ? _model.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Step 3 of 3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 1,
                    minHeight: 6,
                    backgroundColor: Colors.grey,
                    valueColor: const AlwaysStoppedAnimation(primaryPink),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 56,
                    color: primaryPink,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "You're all set!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Welcome to Rendivo, $businessName!\nYou're ready to start managing your appointments.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Details Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Here's the information we have on file for your business.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Business Name: $businessName',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Category: $category',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Contact: $contact',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (_model.phone.isNotEmpty)
                        Text(
                          'Phone: ${_model.phone}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (_model.street.isNotEmpty ||
                          _model.city.isNotEmpty ||
                          _model.state.isNotEmpty ||
                          _model.postalCode.isNotEmpty)
                        Text(
                          'Address: ${_model.street}, ${_model.city} ${_model.state} ${_model.postalCode}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "What's next?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const _NextActionCard(
                  icon: Icons.brush,
                  title: 'Add Your First Service',
                ),

                const SizedBox(height: 12),

                const _NextActionCard(
                  icon: Icons.group_outlined,
                  title: 'Invite Your Team',
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      disabledBackgroundColor: primaryPink.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create My Business',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Go back and edit details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _NextActionCard({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          )
        ],
      ),
    );
  }
}
