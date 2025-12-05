import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'signup_role_screen.dart';
import 'business_dashboard_screen.dart';
import 'customer_dashboard_screen.dart';
import 'staff_dashboard_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryPink = Color(0xFFE66ACF); // buton ve link rengi
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ÜST GÖRSEL
                SizedBox(
                  height: size.height * 0.33,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/login_header.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // BEYAZ KISIM
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      const Text(
                        'Welcome Back!',
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

                      // Email Label
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Email TextField
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
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

                      // Password satırı (label + forgot)
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
                              // TODO: Şifre sıfırlama sayfasına yönlendirme
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

                      // Password TextField
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

                      // Log In butonu
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text;

                            if (email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Email ve şifreyi doldur.')),
                              );
                              return;
                            }

                            try {
                              final cred = await FirebaseService.signInWithEmail(
                                email: email,
                                password: password,
                              );

                              final uid = cred.user?.uid;
                              if (uid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kullanıcı bilgisi alınamadı.')),
                                );
                                return;
                              }

                              final doc = await FirebaseService.getProfile(uid);
                              final data = doc.data();
                              final role = data?['role'] as String?;

                              if (role == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rol bilgisi bulunamadı.')),
                                );
                                return;
                              }

                              Widget targetScreen;
                              switch (role) {
                                case 'business':
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

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Giriş başarılı ✅ ($role)')),
                              );

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => targetScreen),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e')),
                              );
                            }
                          },


                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
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

                      // Alt kısım: Sign Up
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
