import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tells people a newer version is on Google Play, and installs it.
///
/// Uses Play's own flexible update: Play shows the "Update available" sheet,
/// downloads in the background while the app keeps working, and the app
/// restarts into the new version when the person taps Restart. Most people
/// never open the Play Store to look for updates, so without this a fix only
/// reaches them whenever auto-update happens to run.
///
/// The server can also name the oldest build allowed to keep running
/// (`/api/app-config`). A phone older than that gets Play's full-screen
/// update instead, which cannot be skipped — for releases like 1.0.6, whose
/// fix people otherwise never received.
class UpdatePrompt {
  UpdatePrompt._();

  static final UpdatePrompt instance = UpdatePrompt._();

  /// The version someone already said "No thanks" to, and when. Asking on
  /// every launch would be nagging; asking never again means a fix can sit
  /// unseen for months. A newer version, or three days later, asks again.
  static const String _declinedKey = 'update_declined_version';
  static const String _declinedAtKey = 'update_declined_at';
  static const Duration _askAgainAfter = Duration(days: 3);

  static const MethodChannel _channel = MethodChannel(
    'com.ezitech.ezisaver/download',
  );

  bool _checked = false;

  /// Checks once per app launch. Never throws: a sideloaded build, a phone
  /// without Play, or no network all simply mean no prompt.
  Future<void> check(BuildContext context) async {
    if (_checked) return;
    _checked = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      if (info.immediateUpdateAllowed && await _mustUpdate()) {
        // Turning it down just means the same screen on the next launch.
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (!info.flexibleUpdateAllowed) return;

      final version = info.availableVersionCode;
      final prefs = await SharedPreferences.getInstance();
      if (version != null && prefs.getInt(_declinedKey) == version) {
        final at = prefs.getInt(_declinedAtKey) ?? 0;
        final since = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(at),
        );
        if (since < _askAgainAfter) return;
      }

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) {
        if (version != null) {
          await prefs.setInt(_declinedKey, version);
          await prefs.setInt(
            _declinedAtKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        }
        return;
      }

      if (!context.mounted) return;
      _offerRestart(context);
    } catch (_) {
      // Not installed from Play, or Play unavailable: nothing to offer.
    }
  }

  /// Whether this build is older than the oldest the server still allows.
  /// No answer from the server means no: an update is never forced on a
  /// guess.
  Future<bool> _mustUpdate() async {
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      ).get('https://ezisaver.ezitech.org/api/app-config');

      final minimum = (response.data['min_version_code'] as num?)?.toInt() ?? 0;
      if (minimum <= 0) return false;

      final installed = await _channel.invokeMethod<int>('appVersionCode');
      return installed != null && installed < minimum;
    } catch (_) {
      return false;
    }
  }

  void _offerRestart(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF101A36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'A new version of Video Saver is ready.',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.5),
        ),
        action: SnackBarAction(
          label: 'Restart',
          textColor: const Color(0xFF55C8FF),
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (_) {}
          },
        ),
      ),
    );
  }
}
