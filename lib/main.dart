import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/backend_service.dart';

void main() {
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
        fontFamily:
            'Roboto', // özel font kullanıyorsan burayı değiştirebilirsin
      ),
      home: const LoginScreen(),
    );
  }
}
