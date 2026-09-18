import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The download's progress in the notification shade.
///
/// A plain notification, not a foreground service: downloads here take a few
/// seconds, so the process does not need protecting from Android freezing it
/// when backgrounded, and a foreground service would need a Play declaration
/// with a demonstration video.
///
/// Every call is best-effort. A download must never fail because a notification
/// could not be drawn.
class DownloadNotifier {
  DownloadNotifier._();

  static final DownloadNotifier instance = DownloadNotifier._();

  static const MethodChannel _channel = MethodChannel(
    'com.ezitech.ezisaver/download',
  );

  /// Asks for notification permission, which Android 13+ requires before
  /// anything can be posted. Returns false if the user says no — the download
  /// still runs, it just runs without a notification.
  Future<bool> requestPermission() async {
    return await _invoke<bool>('requestPermission') ?? false;
  }

  /// Android sheds notifications from a package that posts more than about
  /// five a second. A fast download changes percent far more often than that,
  /// and the dropped updates included the one that first put the notification
  /// on screen — so updates are spaced out here.
  static const Duration _minimumGap = Duration(milliseconds: 600);

  DateTime? _lastShownAt;
  String? _lastTitle;

  /// Shows, or updates, the running download.
  ///
  /// [progress] is a percentage; pass null while the length is unknown — the
  /// server preparing the video, for instance — to get an indeterminate bar.
  /// Set [force] for updates that must not be dropped, such as the first one.
  Future<void> showProgress({
    required String title,
    required String text,
    int? progress,
    bool force = false,
  }) {
    final now = DateTime.now();
    final last = _lastShownAt;

    // A change of title is the download moving to a new stage — from waiting
    // on the server to saving the file. Never let throttling swallow that.
    final changedStage = title != _lastTitle;

    if (!force &&
        !changedStage &&
        last != null &&
        now.difference(last) < _minimumGap) {
      return Future<void>.value();
    }

    _lastShownAt = now;
    _lastTitle = title;

    return _invoke<void>('show', {
      'title': title,
      'text': text,
      'progress': progress ?? -1,
    });
  }

  /// Replaces the running notification with the outcome.
  Future<void> finish({
    required int downloadId,
    required String title,
    required String text,
    required bool success,
  }) {
    _lastShownAt = null;
    _lastTitle = null;

    return _invoke<void>('finish', {
      'downloadId': downloadId,
      'title': title,
      'text': text,
      'success': success,
    });
  }

  /// Clears the running notification without leaving a result behind.
  Future<void> cancel() {
    _lastShownAt = null;
    _lastTitle = null;
    return _invoke<void>('cancel');
  }

  Future<T?> _invoke<T>(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // A platform without the bridge. Nothing to show.
      return null;
    } on PlatformException catch (e) {
      debugPrint('⚠️ Notification "$method" failed: ${e.message}');
      return null;
    }
  }
}
