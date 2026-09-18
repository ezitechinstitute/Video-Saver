import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'paste_link_screen.dart';
import 'platforms.dart';
import 'services/clipboard_link.dart';
import 'services/download_service.dart';
import 'services/share_service.dart';

/// Key used to remember that the user already went through onboarding.
const String kOnboardingSeenKey = 'onboarding_seen';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

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

class EziDownloadApp extends StatefulWidget {
  final bool onboardingSeen;

  const EziDownloadApp({super.key, this.onboardingSeen = false});

  @override
  State<EziDownloadApp> createState() => _EziDownloadAppState();
}

class _EziDownloadAppState extends State<EziDownloadApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    ShareService.instance
      ..onLink = _openSharedLink
      ..listen();

    // A share that launched the app is waiting on the Android side; it can
    // only be acted on once the first frame has given us a Navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final link = await ShareService.instance.takeLaunchLink();

      if (link != null) {
        _openSharedLink(link);
      } else {
        _checkClipboard();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from TikTok or Instagram with a link copied. Android hands over
    // the clipboard only once the window has focus, hence the short wait.
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 400), _checkClipboard);
    }
  }

  /// Starts downloading a video link the user copied before opening the app.
  Future<void> _checkClipboard() async {
    // Onboarding first; and one download at a time, since they share the
    // progress notification.
    if (DownloadService.instance.isBusy) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(kOnboardingSeenKey) ?? false)) return;
    } catch (_) {
      return;
    }

    final link = await ClipboardLinkWatcher.instance.takeNewLink();
    if (link == null || !mounted) return;

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF101A36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'Downloading the ${link.platform.name} link you copied.',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
        ),
      ),
    );

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => PasteLinkScreen(
          platformName: link.platform.name,
          initialLink: link.url,
          autoStart: true,
        ),
      ),
    );
  }

  /// Opens the download screen for a link shared in from another app.
  void _openSharedLink(String link) {
    final uri = Uri.tryParse(link.trim());

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _sharedLinkRejected('That does not look like a video link.');
      return;
    }

    final platform = platformForUrl(uri);

    if (platform == null) {
      _sharedLinkRejected('Video Saver cannot download from ${uri.host} yet.');
      return;
    }

    // The same link may still be on the clipboard; it is already handled.
    ClipboardLinkWatcher.instance.markHandled(link);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => PasteLinkScreen(
          platformName: platform.name,
          initialLink: link.trim(),
          autoStart: true,
        ),
      ),
    );
  }

  void _sharedLinkRejected(String message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VideoSaver',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      // Every screen is dark navy, but the theme is light, so Android drew
      // dark status bar icons that could barely be seen. Light icons, app wide.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: child!,
      ),
      home: widget.onboardingSeen
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
