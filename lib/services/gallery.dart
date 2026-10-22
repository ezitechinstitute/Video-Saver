import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

/// Puts videos into the phone's gallery, and says which phone it is.
///
/// Saving is done on the Android side (GallerySaver.kt) rather than by the
/// gal plugin: gal put videos under Pictures/ with no MIME type and no
/// pending flag, and on at least one phone in October 2026 fully downloaded
/// videos never appeared in the gallery. gal is still used for the one thing
/// it is needed for — asking for storage permission on Android 9 and older.
class Gallery {
  Gallery._();

  static const MethodChannel _channel = MethodChannel(
    'com.ezitech.ezisaver/download',
  );

  static int? _sdk;
  static String? _device;

  /// Saves the video at [path] to Movies/EziDownload as [name].
  ///
  /// Returns the gallery URI, which [open] accepts. Throws with a readable
  /// reason when the phone refuses.
  static Future<String> saveVideo(String path, String name) async {
    await _ensurePermission();

    try {
      final uri = await _channel.invokeMethod<String>('saveVideo', {
        'path': path,
        'name': name,
      });
      if (uri == null || uri.isEmpty) {
        throw Exception('The gallery did not confirm the video was saved.');
      }
      return uri;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'The video could not be saved to the gallery.');
    }
  }

  /// Opens a saved video in the phone's player. Returns false if none could.
  static Future<bool> open(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('openVideo', {'uri': uri}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// "Xiaomi Redmi Note 12 / Android 13 (33)", for failure reports.
  static Future<String> deviceLabel() async {
    await _loadDevice();
    return _device ?? 'unknown device';
  }

  static Future<void> _loadDevice() async {
    if (_device != null) return;
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('deviceInfo');
      _device = info?['label'] as String?;
      _sdk = info?['sdk'] as int?;
    } catch (_) {}
  }

  /// Android 10 and later save through MediaStore and need no permission;
  /// only older phones write a real file into shared storage.
  static Future<void> _ensurePermission() async {
    await _loadDevice();
    final sdk = _sdk;
    if (sdk != null && sdk >= 29) return;

    if (await Gal.hasAccess(toAlbum: true)) return;
    if (!await Gal.requestAccess(toAlbum: true)) {
      throw Exception(
        'Video Saver needs storage permission to put videos in your gallery.',
      );
    }
  }
}
