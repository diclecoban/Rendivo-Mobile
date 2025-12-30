import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/business_dashboard_screen.dart';
import 'screens/customer_dashboard_screen.dart';
import 'screens/staff_dashboard_screen.dart';
import 'services/backend_service.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';

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
    final Widget home;
    if (!hasSession) {
      home = const LoginScreen();
    } else {
      final resolvedUser = user!;
      switch (resolvedUser.role) {
        case 'admin':
          home = const AdminDashboardScreen();
          break;
        case 'business_owner':
          home = const BusinessDashboardScreen();
          break;
        case 'staff':
          home = const StaffDashboardScreen();
          break;
        case 'customer':
        default:
          home = const CustomerDashboardScreen();
          break;
      }
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Rendivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFE66ACF),
        scaffoldBackgroundColor: Colors.white,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        fontFamily:
            'Roboto', // özel font kullanıyorsan burayı değiştirebilirsin
      ),
      home: home,
    );
  }
}
