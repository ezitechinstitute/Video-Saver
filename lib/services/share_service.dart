import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Links shared into the app from another app's share sheet.
///
/// The Android side ([MainActivity]) picks the URL out of the shared text and
/// either parks it until Dart asks — when the share launched the app — or
/// pushes it across if the app was already open.
class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  static const MethodChannel _channel = MethodChannel(
    'com.ezitech.ezisaver/share',
  );

  /// Called when a link arrives while the app is already running.
  void Function(String link)? onLink;

  void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'sharedLink') return null;

      final link = call.arguments as String?;

      if (link != null && link.isNotEmpty) {
        debugPrint('🔗 Link shared into the app: $link');
        onLink?.call(link);
      }

      return null;
    });
  }

  /// The link the app was launched with, if any. Returns it once.
  Future<String?> takeLaunchLink() async {
    try {
      final link = await _channel.invokeMethod<String>('takeSharedLink');

      if (link != null && link.isNotEmpty) {
        debugPrint('🔗 App launched with a shared link: $link');
      }

      return link;
    } on MissingPluginException {
      // Nothing on the other end — a platform that does not receive shares.
      return null;
    } on PlatformException catch (e) {
      debugPrint('⚠️ Could not read the shared link: ${e.message}');
      return null;
    }
  }
}
