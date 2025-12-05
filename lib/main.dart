import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';

// If you run `flutterfire configure` this file will be generated.
// If you don't have it, Firebase.initializeApp() below will still work for
// default options but it's recommended to generate firebase_options.dart.
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // ignore: avoid_print
    print('Firebase init error: $e');
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
