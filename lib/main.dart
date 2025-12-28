import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/login_screen.dart';
import 'services/backend_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  const apiBase = String.fromEnvironment('API_BASE_URL');
  if (apiBase.isNotEmpty) {
    BackendService.instance.setBaseUrl(apiBase);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const LoginScreen(),
    );
  }
}
