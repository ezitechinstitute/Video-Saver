import 'package:flutter/material.dart';
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
class UpdatePrompt {
  UpdatePrompt._();

  static final UpdatePrompt instance = UpdatePrompt._();

  /// The version someone already said "No thanks" to. Asking again for the
  /// same version on every launch would be nagging; a newer one is fair game.
  static const String _declinedKey = 'update_declined_version';

  bool _checked = false;

  /// Checks once per app launch. Never throws: a sideloaded build, a phone
  /// without Play, or no network all simply mean no prompt.
  Future<void> check(BuildContext context) async {
    if (_checked) return;
    _checked = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (!info.flexibleUpdateAllowed) return;

      final version = info.availableVersionCode;
      final prefs = await SharedPreferences.getInstance();
      if (version != null && prefs.getInt(_declinedKey) == version) return;

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) {
        if (version != null) await prefs.setInt(_declinedKey, version);
        return;
      }

      if (!context.mounted) return;
      _offerRestart(context);
    } catch (_) {
      // Not installed from Play, or Play unavailable: nothing to offer.
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
