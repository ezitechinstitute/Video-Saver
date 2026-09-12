import 'package:flutter/material.dart';

import 'platform_glyphs.dart';

/// A source the app can pull videos from.
///
/// YouTube is deliberately absent. Downloading YouTube content violates the
/// YouTube Terms of Service, and Google Play rejected version 7 of this app
/// under the Device and Network Abuse policy for exactly that. Do not add it
/// back — the store listing and screenshots must stay free of it too.
class VideoPlatform {
  final String name;

  /// The mark drawn on the tile. Custom shapes rather than the platforms' own
  /// logos, which are theirs.
  final PlatformGlyph glyph;

  /// Brand colours for the tile, top-left to bottom-right.
  final List<Color> gradient;

  /// Page to open when the user wants to browse this platform in-app.
  /// Empty means the platform cannot be browsed (the "More" tile).
  final String browseUrl;

  /// Hosts that belong to this platform, without the `www.` prefix.
  final List<String> hosts;

  /// Regular expressions, as source strings, for links that point at an actual
  /// video rather than a feed, profile or login page. Matched case-insensitively
  /// against the full URL. Kept as strings because `RegExp` cannot be `const`.
  final List<String> videoPatterns;

  const VideoPlatform({
    required this.name,
    required this.glyph,
    required this.gradient,
    required this.browseUrl,
    this.hosts = const [],
    this.videoPatterns = const [],
  });

  Color get accent => gradient.first;

  bool get canBrowse => browseUrl.isNotEmpty;

  /// Whether [uri] belongs to this platform at all (any page on it).
  bool matchesHost(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst('www.', '');
    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }

  /// Whether [uri] points at a single video.
  ///
  /// The old build sent whatever page the WebView happened to be showing —
  /// a homepage or a login screen — straight to the server, which is why
  /// every browse-based download failed. This is the guard for that.
  bool isVideoUrl(Uri uri) {
    if (!matchesHost(uri)) return false;
    if (videoPatterns.isEmpty) return true;

    final url = uri.toString();
    return videoPatterns.any(
      (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(url),
    );
  }
}

/// Every platform the app offers, in the order they appear on the home grid.
const List<VideoPlatform> kPlatforms = [
  VideoPlatform(
    name: 'TikTok',
    glyph: PlatformGlyph.equaliser,
    gradient: [Color(0xFF25F4EE), Color(0xFFFE2C55)],
    browseUrl: 'https://www.tiktok.com/',
    hosts: ['tiktok.com'],
    videoPatterns: [
      // www.tiktok.com/@user/video/1234567890
      r'tiktok\.com/@[^/]+/video/\d+',
      // vm.tiktok.com/ZSVw9tKAe  and  www.tiktok.com/t/ZSVw9tKAe
      r'(vm|vt)\.tiktok\.com/[\w-]{4,}',
      r'tiktok\.com/t/[\w-]{4,}',
    ],
  ),
  VideoPlatform(
    name: 'Instagram',
    glyph: PlatformGlyph.reel,
    gradient: [Color(0xFFF9CE34), Color(0xFFEE2A7B), Color(0xFF6228D7)],
    browseUrl: 'https://www.instagram.com',
    hosts: ['instagram.com', 'instagr.am'],
    videoPatterns: [r'instagram\.com/(reel|reels|p|tv)/[\w-]+'],
  ),
  VideoPlatform(
    name: 'Facebook',
    glyph: PlatformGlyph.person,
    gradient: [Color(0xFF1877F2), Color(0xFF0A53BE)],
    browseUrl: 'https://www.facebook.com',
    hosts: ['facebook.com', 'fb.watch', 'fb.com'],
    videoPatterns: [
      r'facebook\.com/[^/]+/videos/\d+',
      r'facebook\.com/(reel|video)/',
      r'facebook\.com/share/[rv]/[\w-]+',
      r'facebook\.com/watch/?\?v=\d+',
      r'fb\.watch/[\w-]+',
    ],
  ),
  VideoPlatform(
    name: 'Twitter / X',
    glyph: PlatformGlyph.post,
    gradient: [Color(0xFF3A4045), Color(0xFF0B0B0C)],
    browseUrl: 'https://x.com',
    hosts: ['x.com', 'twitter.com'],
    // Only a post can hold a video. Feeds, profiles and the /i/... login
    // and onboarding pages cannot — every recorded X failure was one of those.
    videoPatterns: [r'(x|twitter)\.com/[^/]+/status/\d+'],
  ),
  VideoPlatform(
    name: 'Dailymotion',
    glyph: PlatformGlyph.playCircle,
    gradient: [Color(0xFF0EF0A0), Color(0xFF00B39B)],
    browseUrl: 'https://www.dailymotion.com',
    hosts: ['dailymotion.com', 'dai.ly'],
    videoPatterns: [r'dailymotion\.com/video/[\w-]+', r'dai\.ly/[\w-]+'],
  ),
  VideoPlatform(
    name: 'Vimeo',
    glyph: PlatformGlyph.film,
    gradient: [Color(0xFF1AB7EA), Color(0xFF0D6E90)],
    browseUrl: 'https://vimeo.com',
    hosts: ['vimeo.com'],
    videoPatterns: [
      r'vimeo\.com/\d+',
      r'vimeo\.com/video/\d+',
      r'vimeo\.com/channels/[^/]+/\d+',
    ],
  ),
  VideoPlatform(
    name: 'More',
    glyph: PlatformGlyph.grid,
    gradient: [Color(0xFF6F7CFF), Color(0xFF9B6DFF)],
    browseUrl: '',
  ),
];

/// The platform [name] belongs to, or null for "More" and anything unknown.
VideoPlatform? platformByName(String name) {
  for (final platform in kPlatforms) {
    if (platform.name == name) return platform;
  }
  return null;
}

/// The platform a pasted [uri] belongs to, regardless of which tile the user
/// came from. Lets us tell someone they pasted an Instagram link on the
/// TikTok screen instead of just calling it invalid.
VideoPlatform? platformForUrl(Uri uri) {
  for (final platform in kPlatforms) {
    if (platform.matchesHost(uri)) return platform;
  }
  return null;
}

/// Strips tracking parameters and fragments, which the extractor chokes on.
/// Links shared from the platform apps always carry them (`igsi`, `stkn`,
/// `fbclid`, `utm_*`, …).
///
/// Parameters that identify the video itself are kept — `facebook.com/watch/?v=123`
/// is nothing without its `v`.
const Set<String> _essentialParams = {'v'};

String cleanVideoUrl(Uri uri) {
  if (!uri.hasQuery && !uri.hasFragment) return uri.toString();

  final kept = <String, String>{
    for (final entry in uri.queryParameters.entries)
      if (_essentialParams.contains(entry.key.toLowerCase()))
        entry.key: entry.value,
  };

  // `replace(queryParameters: null)` keeps the existing query rather than
  // clearing it, so an empty result has to go through `query: ''`.
  var cleaned =
      (kept.isEmpty
              ? uri.replace(query: '', fragment: '')
              : uri.replace(queryParameters: kept, fragment: ''))
          .toString();

  while (cleaned.endsWith('?') || cleaned.endsWith('#')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }

  return cleaned.isEmpty ? uri.toString() : cleaned;
}
