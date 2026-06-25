// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils/constants.dart';
import 'services/config_service.dart';
import 'services/guard_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load runtime configuration first — everything else reads from it.
  await ConfigService().load();

  // Restore manually overridden guard across restarts.
  await GuardService().loadPersistedOverride();

  // Force landscape for tablet kiosk
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Fullscreen immersive mode for kiosk
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const PSAVisitorApp());
}

class PSAVisitorApp extends StatelessWidget {
  const PSAVisitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSA Visitor Logging System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.psaBlue,
          primary: AppColors.psaBlue,
          secondary: AppColors.psaAccent,
          surface: AppColors.cardBg,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.psaBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.psaBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}