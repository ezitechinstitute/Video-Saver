import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onboarding_screen.dart';

void main() {
  runApp(const EziDownloadApp());
}

class EziDownloadApp extends StatelessWidget {
  const EziDownloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VideoSaver',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const OnboardingScreen(),
    );
  }
}
