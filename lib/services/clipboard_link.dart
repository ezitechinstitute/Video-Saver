import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platforms.dart';

/// A video link the user copied, ready to download.
class CopiedLink {
  final VideoPlatform platform;

  /// The link with tracking parameters removed.
  final String url;

  const CopiedLink(this.platform, this.url);
}

final RegExp _urlPattern = RegExp(r'https?://\S+');

/// The first link in [text] that points at a video on a supported platform.
///
/// Apps rarely copy a bare link; TikTok and Instagram wrap it in a caption,
/// so the link is picked out of the surrounding text. Feeds, profiles and
/// anything not on a supported platform are ignored.
CopiedLink? findVideoLink(String? text) {
  if (text == null) return null;

  for (final match in _urlPattern.allMatches(text)) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null) continue;

    final platform = platformForUrl(uri);
    if (platform == null || !platform.isVideoUrl(uri)) continue;

    return CopiedLink(platform, cleanVideoUrl(uri));
  }

  return null;
}

/// Picks up a video link the user copied before opening the app.
///
/// Android only lets an app read the clipboard while it is on screen, so this
/// runs when the app opens or comes back to the front, not in the background.
class ClipboardLinkWatcher {
  ClipboardLinkWatcher._();

  static final ClipboardLinkWatcher instance = ClipboardLinkWatcher._();

  static const String _lastLinkKey = 'last_auto_link';

  /// A new video link on the clipboard, or null.
  ///
  /// A link is handed out once. Coming back to the app with the same link
  /// still copied must not download the video again.
  Future<CopiedLink?> takeNewLink() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final link = findVideoLink(data?.text);
      if (link == null) return null;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastLinkKey) == link.url) return null;

      await prefs.setString(_lastLinkKey, link.url);
      return link;
    } catch (_) {
      // No clipboard access, or no storage: just do nothing.
      return null;
    }
  }

  /// Records a link that reached the app another way, by sharing, so the
  /// same link on the clipboard does not start a second download.
  Future<void> markHandled(String url) async {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLinkKey, cleanVideoUrl(uri));
    } catch (_) {}
  }
}
