import 'package:flutter_test/flutter_test.dart';

import 'package:ezi_download/services/clipboard_link.dart';

void main() {
  test('a bare video link is picked up', () {
    final link = findVideoLink('https://vm.tiktok.com/ZSVcQJKB9/');

    expect(link, isNotNull);
    expect(link!.platform.name, 'TikTok');
    expect(link.url, 'https://vm.tiktok.com/ZSVcQJKB9/');
  });

  test('a link wrapped in a caption is picked out and cleaned', () {
    final link = findVideoLink(
      'Watch this reel! https://www.instagram.com/reel/Dc8IQPzAPl7/?igsh=abc123 via Instagram',
    );

    expect(link, isNotNull);
    expect(link!.platform.name, 'Instagram');
    expect(link.url, 'https://www.instagram.com/reel/Dc8IQPzAPl7/');
  });

  test('ordinary copied text is ignored', () {
    expect(findVideoLink('meeting at 5pm'), isNull);
    expect(findVideoLink(''), isNull);
    expect(findVideoLink(null), isNull);
  });

  test('pages that hold no single video are ignored', () {
    expect(findVideoLink('https://www.tiktok.com/'), isNull);
    expect(findVideoLink('https://x.com/i/jf/onboarding/web'), isNull);
  });

  test('links to unsupported sites are ignored, YouTube included', () {
    expect(findVideoLink('https://example.com/video/1'), isNull);
    expect(
      findVideoLink('https://www.youtube.com/watch?v=E7HR-E-5M0U'),
      isNull,
    );
    expect(findVideoLink('https://youtu.be/E7HR-E-5M0U'), isNull);
  });

  test('the first video link wins when several are copied', () {
    final link = findVideoLink(
      'https://example.com/a then https://www.facebook.com/watch/?v=1234567890',
    );

    expect(link!.platform.name, 'Facebook');
    expect(link.url, contains('v=1234567890'));
  });
}
