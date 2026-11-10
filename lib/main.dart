
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/main_page.dart';
import 'theme/pawpulse_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Global PawPulse theme
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: PawPulseTheme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PawPulseTheme.turquoise,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: PawPulseTheme.turquoise,
          foregroundColor: PawPulseTheme.darkNavy,
          elevation: 0,
          centerTitle: false,
        ),
      ),

      home: const MainPage(),
    );
  }
}
