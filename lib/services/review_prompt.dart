import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play Store rating, once, after the app has been useful.
///
/// Google's in-app review sheet appears over the app; the user rates or
/// dismisses it without leaving. Play never tells us which they did, and it
/// may quietly show nothing at all when the account is over its quota — so
/// the only workable rule is to ask once and never again, whatever happened.
/// That is also what was asked for: someone who has rated, or waved the sheet
/// away, should not see it a second time.
class ReviewPrompt {
  ReviewPrompt._();

  static final ReviewPrompt instance = ReviewPrompt._();

  /// Set the moment the sheet is requested, so a rating, a dismissal and a
  /// sheet Play decided not to draw all count as "asked".
  static const String _askedKey = 'review_asked';

  /// Videos saved so far, until the question has been asked.
  static const String _savesKey = 'review_saves';

  /// Asking after the first save feels like a toll; by the second the app has
  /// visibly done its job twice.
  static const int _savesBeforeAsking = 2;

  bool _asking = false;

  /// The sheet to show. Swapped out in tests, which have no Play Store.
  InAppReview reviews = InAppReview.instance;

  /// Call after a video reaches the gallery.
  ///
  /// Counts the save and, once there have been enough of them, shows the
  /// rating sheet. Never throws: a rating is not worth a failed download.
  Future<void> recordSave() async {
    if (_asking) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;

      final saves = (prefs.getInt(_savesKey) ?? 0) + 1;
      await prefs.setInt(_savesKey, saves);
      if (saves < _savesBeforeAsking) return;

      _asking = true;

      final review = reviews;
      if (!await review.isAvailable()) {
        // Sideloaded, or no Play Store on the device. Leave the count alone
        // so the question still gets asked on a device that can show it.
        _asking = false;
        return;
      }

      // Asked before the sheet is requested, not after: if the call throws
      // halfway, the user has still had their moment interrupted once.
      await prefs.setBool(_askedKey, true);
      await review.requestReview();
    } catch (_) {
      // No storage, no Play Store, no sheet: nothing here is worth surfacing.
    } finally {
      _asking = false;
    }
  }
}
