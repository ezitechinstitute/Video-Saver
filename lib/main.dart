import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Key used to remember that the user already went through onboarding.
const String kOnboardingSeenKey = 'onboarding_seen';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool onboardingSeen = false;

  try {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(kOnboardingSeenKey) ?? false;
  } catch (e) {
    debugPrint('⚠️ Could not read onboarding flag: $e');
  }

  runApp(EziDownloadApp(onboardingSeen: onboardingSeen));
}

class EziDownloadApp extends StatelessWidget {
  final bool onboardingSeen;

  const EziDownloadApp({super.key, this.onboardingSeen = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VideoSaver',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: onboardingSeen ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
