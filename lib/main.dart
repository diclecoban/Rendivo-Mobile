import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/business_dashboard_screen.dart';
import 'screens/customer_dashboard_screen.dart';
import 'screens/staff_dashboard_screen.dart';
import 'services/backend_service.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';

const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(18));
const Duration _buttonAnimDuration = Duration(milliseconds: 180);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  await SessionService.instance.init();
  const apiBase = String.fromEnvironment('API_BASE_URL');
  if (apiBase.isNotEmpty) {
    BackendService.instance.setBaseUrl(apiBase);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    SessionService.instance.registerSessionExpiredHandler(() {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;
    final user = session.currentUser;
    final hasSession = session.hasValidSession;
    final baseTextTheme =
        GoogleFonts.nunitoTextTheme(ThemeData.light().textTheme);
    final textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        textStyle:
            baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      headlineMedium: GoogleFonts.splineSans(
        textStyle:
            baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      headlineSmall: GoogleFonts.splineSans(
        textStyle:
            baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle:
            baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.35),
      labelLarge: GoogleFonts.splineSans(
        textStyle:
            baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Rendivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFE66ACF),
        scaffoldBackgroundColor: Colors.white,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SoftFadePageTransitionsBuilder(),
            TargetPlatform.iOS: _SoftFadePageTransitionsBuilder(),
            TargetPlatform.linux: _SoftFadePageTransitionsBuilder(),
            TargetPlatform.macOS: _SoftFadePageTransitionsBuilder(),
            TargetPlatform.windows: _SoftFadePageTransitionsBuilder(),
          },
        ),
        fontFamily: GoogleFonts.nunito().fontFamily,
        textTheme: textTheme,
        primaryTextTheme: textTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            animationDuration: _buttonAnimDuration,
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: _buttonRadius),
            ),
            padding: MaterialStateProperty.resolveWith(
              (states) {
                final base =
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
                if (states.contains(MaterialState.pressed) ||
                    states.contains(MaterialState.hovered)) {
                  return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
                }
                return base;
              },
            ),
            backgroundColor: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.disabled)
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFFE66ACF),
            ),
            foregroundColor: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.disabled)
                  ? Colors.black45
                  : Colors.white,
            ),
            elevation: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.pressed) ||
                      states.contains(MaterialState.hovered)
                  ? 7
                  : 3,
            ),
            shadowColor: MaterialStateProperty.all(
              const Color(0xFFE66ACF).withOpacity(0.35),
            ),
            overlayColor: MaterialStateProperty.all(
              Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            animationDuration: _buttonAnimDuration,
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: _buttonRadius),
            ),
            side: MaterialStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(MaterialState.disabled)
                    ? Colors.grey.shade300
                    : const Color(0xFFE66ACF),
                width: 1.3,
              ),
            ),
            padding: MaterialStateProperty.resolveWith(
              (states) {
                final base =
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12);
                if (states.contains(MaterialState.pressed) ||
                    states.contains(MaterialState.hovered)) {
                  return const EdgeInsets.symmetric(horizontal: 20, vertical: 13);
                }
                return base;
              },
            ),
            foregroundColor: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.disabled)
                  ? Colors.black38
                  : const Color(0xFFE66ACF),
            ),
            overlayColor: MaterialStateProperty.all(
              const Color(0xFFE66ACF).withOpacity(0.08),
            ),
            elevation: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.pressed) ? 4 : 0,
            ),
            shadowColor: MaterialStateProperty.all(
              const Color(0xFFE66ACF).withOpacity(0.2),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            animationDuration: _buttonAnimDuration,
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: _buttonRadius),
            ),
            padding: MaterialStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            foregroundColor: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.disabled)
                  ? Colors.black54
                  : const Color(0xFFE66ACF),
            ),
            overlayColor: MaterialStateProperty.all(
              const Color(0xFFE66ACF).withOpacity(0.08),
            ),
          ),
        ),
      ),
      home: !hasSession
          ? const LoginScreen()
          : switch (user!.role) {
              'admin' => const AdminDashboardScreen(),
              'business_owner' => const BusinessDashboardScreen(),
              'staff' => const StaffDashboardScreen(),
              _ => const CustomerDashboardScreen(),
            },
    );
  }
}

/// Applies a subtle fade between pages across the entire app so transitions feel soft.
class _SoftFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: child,
    );
  }
}
