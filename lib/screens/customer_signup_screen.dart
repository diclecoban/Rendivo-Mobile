import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/firebase_service.dart';
import 'customer_dashboard_screen.dart';

class CustomerSignUpScreen extends StatefulWidget {
  const CustomerSignUpScreen({super.key});

  @override
  State<CustomerSignUpScreen> createState() => _CustomerSignUpScreenState();
}

class _CustomerSignUpScreenState extends State<CustomerSignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isTermsAccepted = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + isim
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE66ACF),
                            Color(0xFFFB9BEF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Rendivo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start managing your appointments with ease.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 24),

                // Google button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Google ile devam et
                    },
                    icon: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Apple button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Apple ile devam et
                    },
                    icon:
                        const Icon(Icons.apple, size: 22, color: Colors.black),
                    label: const Text(
                      'Continue with Apple',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // OR divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey.shade300),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey.shade300),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // First Name
                const Text(
                  'First Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _firstNameController,
                  hintText: 'Enter your first name',
                ),

                const SizedBox(height: 16),

                // Last Name
                const Text(
                  'Last Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _lastNameController,
                  hintText: 'Enter your last name',
                ),

                const SizedBox(height: 16),

                // Email
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                // Phone
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneController,
                  hintText: '(123) 456-7890',
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                // Password
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: primaryPink,
                        width: 1.4,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),
                const Text(
                  'Weak password',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 16),

                // Terms & Privacy
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _isTermsAccepted,
                      onChanged: (value) {
                        setState(() {
                          _isTermsAccepted = value ?? false;
                        });
                      },
                      activeColor: primaryPink,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Wrap(
                        children: [
                          const Text(
                            'I agree to the ',
                            style: TextStyle(fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () {
                              // TODO: Terms of Service sayfası
                            },
                            child: const Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryPink,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' and ',
                            style: TextStyle(fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () {
                              // TODO: Privacy Policy sayfası
                            },
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryPink,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            '.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isTermsAccepted
                        ? () async {
                            final firstName = _firstNameController.text.trim();
                            final lastName = _lastNameController.text.trim();
                            final email = _emailController.text.trim();
                            final phone = _phoneController.text.trim();
                            final password = _passwordController.text;

                            if (firstName.isEmpty || email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lütfen gerekli alanları doldurun.')),
                              );
                              return;
                            }

                            try {
                              await FirebaseService.signUpWithEmail(
                                email: email,
                                password: password,
                                profileData: {
                                  'firstName': firstName,
                                  'lastName': lastName,
                                  'phone': phone,
                                  'role': 'customer',
                                },
                              );

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CustomerDashboardScreen(),
                                ),
                                (route) => false,
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Kayıt hatası: $e')),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPink,
                      disabledBackgroundColor: primaryPink.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Already have an account? Log in
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Login ekranına dön (stack'teki ilk route)
                          Navigator.popUntil(
                            context,
                            (route) => route.isFirst,
                          );
                        },
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryPink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: primaryPink,
            width: 1.4,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
      ),
    );
  }
}
