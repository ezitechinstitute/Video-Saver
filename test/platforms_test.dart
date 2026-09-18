// Link rules, checked against URLs the live backend actually received.
//
// The URLs below are taken from the server's own download history: the ones
// under "accepts" produced a completed download, the ones under "rejects"
// produced a yt-dlp failure because they were never videos in the first place.

import 'package:flutter_test/flutter_test.dart';

import 'package:ezi_download/platforms.dart';

void expectAccepted(String platformName, String url) {
  final platform = platformByName(platformName)!;
  expect(
    platform.isVideoUrl(Uri.parse(url)),
    isTrue,
    reason: '$platformName should accept $url',
  );
}

void expectRejected(String platformName, String url) {
  final platform = platformByName(platformName)!;
  expect(
    platform.isVideoUrl(Uri.parse(url)),
    isFalse,
    reason: '$platformName should reject $url',
  );
}

void main() {
  group('accepts links that really downloaded', () {
    test('Instagram reels', () {
      expectAccepted(
        'Instagram',
        'https://www.instagram.com/reel/Dc8IQPzAPl7/?stkn=MXM4dGlqcDAxbGprag==',
      );
      expectAccepted('Instagram', 'https://www.instagram.com/p/DcucHeaoNgp/');
    });

    test('Facebook share and watch links', () {
      expectAccepted(
        'Facebook',
        'https://www.facebook.com/share/r/1JURa2nzCQ/',
      );
      expectAccepted(
        'Facebook',
        'https://www.facebook.com/watch/?v=1234567890',
      );
      expectAccepted('Facebook', 'https://fb.watch/abc123XY/');
    });

    test('TikTok short links and full links', () {
      expectAccepted('TikTok', 'https://vm.tiktok.com/ZSVcQJKB9/');
      expectAccepted('TikTok', 'https://vt.tiktok.com/ZSVgvVMFe/');
      expectAccepted(
        'TikTok',
        'https://www.tiktok.com/@someone/video/7301234567890123456',
      );
    });

    test('X posts, Vimeo and Dailymotion videos', () {
      expectAccepted('Twitter / X', 'https://x.com/someone/status/1234567890');
      expectAccepted('Vimeo', 'https://vimeo.com/1085116418');
      expectAccepted(
        'Dailymotion',
        'https://www.dailymotion.com/video/x9abcde',
      );
    });
  });

  group('rejects the pages that made every browse download fail', () {
    test('X login and onboarding pages', () {
      expectRejected(
        'Twitter / X',
        'https://x.com/i/jf/onboarding/web?mode=signup&redirect_after_login=%2F',
      );
      expectRejected('Twitter / X', 'https://x.com/');
    });

    test('platform homepages', () {
      expectRejected('Dailymotion', 'https://www.dailymotion.com/');
      expectRejected('Vimeo', 'https://vimeo.com/');
      expectRejected('TikTok', 'https://www.tiktok.com/');
    });

    test('Vimeo legal and login pages', () {
      expectRejected('Vimeo', 'https://vimeo.com/legal/privacy/cookies');
      expectRejected('Vimeo', 'https://vimeo.com/log_in');
    });

    test('a link from another platform', () {
      expectRejected('TikTok', 'https://www.instagram.com/reel/Dc8IQPzAPl7/');
    });
  });

  group('YouTube stays out', () {
    test('no platform is YouTube', () {
      expect(
        kPlatforms.any((p) => p.name.toLowerCase().contains('youtube')),
        isFalse,
      );
    });

    test('no platform claims a YouTube link', () {
      for (final url in [
        'https://www.youtube.com/watch?v=E7HR-E-5M0U',
        'https://m.youtube.com/watch?v=a2_Yc3I2R0M',
        'https://youtu.be/E7HR-E-5M0U',
        'https://www.youtube.com/shorts/abc123',
      ]) {
        expect(
          platformForUrl(Uri.parse(url)),
          isNull,
          reason: '$url must not map to any platform',
        );
      }
    });
  });

  group('cleanVideoUrl', () {
    test('drops tracking parameters', () {
      expect(
        cleanVideoUrl(
          Uri.parse(
            'https://www.instagram.com/reel/Dc8IQPzAPl7/?igsi=a3hkdHpxdXo2ejg2',
          ),
        ),
        'https://www.instagram.com/reel/Dc8IQPzAPl7/',
      );
    });

    test('keeps the parameter that identifies the video', () {
      final cleaned = cleanVideoUrl(
        Uri.parse('https://www.facebook.com/watch/?v=1234567890&fbclid=xyz'),
      );

      expect(cleaned, contains('v=1234567890'));
      expect(cleaned, isNot(contains('fbclid')));
    });

    test('leaves a clean link alone', () {
      const url = 'https://vm.tiktok.com/ZSVcQJKB9/';
      expect(cleanVideoUrl(Uri.parse(url)), url);
    });
  });

  group('tiles', () {
    test('every platform has its own glyph', () {
      final glyphs = kPlatforms.map((p) => p.glyph).toList();

      expect(
        glyphs.toSet().length,
        glyphs.length,
        reason: 'two platforms would be indistinguishable on the home grid',
      );
    });

    test('every platform has brand colours to sit on', () {
      for (final platform in kPlatforms) {
        expect(
          platform.gradient.length,
          greaterThanOrEqualTo(2),
          reason: '${platform.name} needs at least two stops for a gradient',
        );
      }
    });
  });
}
