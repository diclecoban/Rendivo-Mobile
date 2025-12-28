import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_snackbar.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/notification_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'business_dashboard_screen.dart';
import 'customer_dashboard_screen.dart';
import 'email_verification_code_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_role_screen.dart';
import 'staff_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (form == null) return;

    final isValid = form.validate();
    if (!isValid) {
      setState(() {
        _autoValidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = await AuthService.signIn(email, password);
      if (!mounted) return;

      final token = await NotificationService.instance.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await BackendService.instance.registerDeviceToken(token: token);
          NotificationService.instance.listenForTokenRefresh((newToken) async {
            try {
              await BackendService.instance.registerDeviceToken(token: newToken);
            } catch (_) {}
          });
        } catch (_) {
          // Ignore token registration failures to avoid blocking login.
        }
      }

      Widget targetScreen;
      switch (user.role) {
        case 'admin':
          targetScreen = const AdminDashboardScreen();
          break;
        case 'business_owner':
          targetScreen = const BusinessDashboardScreen();
          break;
        case 'staff':
          targetScreen = const StaffDashboardScreen();
          break;
        case 'customer':
        default:
          targetScreen = const CustomerDashboardScreen();
          break;
      }

      AppSnackbar.show(context, 'Welcome back, ${user.fullName}!');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => targetScreen),
      );
    } on AppException catch (e) {
      final details = e.details;
      final emailNotVerified =
          e.statusCode == 403 && details?['emailVerified'] == false;
      if (emailNotVerified) {
        final emailValue =
            details?['email']?.toString() ?? _emailController.text.trim();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationCodeScreen(email: emailValue),
          ),
        );
        return;
      }
      AppSnackbar.show(context, e.message);
    } catch (_) {
      AppSnackbar.show(
        context,
        'Something unexpected happened. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size.height * 0.33,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/login_header.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Log in to manage your appointments.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => validateEmail(value ?? ''),
                          decoration: InputDecoration(
                            hintText: 'you@example.com',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: primaryPink,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9F9F9),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot your password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryPink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Please enter your password.';
                            }
                            // TODO: Re-enable the 8-character requirement once backend enforces it again.
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
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
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupRoleScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Sign Up',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
