// Smoke tests for the VideoSaver app shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ezi_download/downloads_screen.dart';
import 'package:ezi_download/main.dart';
import 'package:ezi_download/paste_link_screen.dart';

void main() {
  testWidgets('shows onboarding on a fresh install', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EziDownloadApp(onboardingSeen: false));
    await tester.pump();

    expect(find.text('Skip'), findsOneWidget);
    // The heading is a RichText (two coloured spans), so opt into rich text.
    expect(
      find.textContaining('Welcome to Video', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('skips onboarding once it has been seen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EziDownloadApp(onboardingSeen: true));
    await tester.pump();

    expect(find.text('Skip'), findsNothing);
    expect(find.text('Popular Platforms'), findsOneWidget);
  });

  testWidgets('a shared link arrives already filled in', (
    WidgetTester tester,
  ) async {
    const shared = 'https://vm.tiktok.com/ZSVcQJKB9/';

    await tester.pumpWidget(
      const MaterialApp(
        home: PasteLinkScreen(platformName: 'TikTok', initialLink: shared),
      ),
    );
    await tester.pump();

    expect(find.text(shared), findsOneWidget);
  });

  testWidgets('downloads screen explains itself when empty', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('My Downloads'), findsOneWidget);
    expect(find.text('Nothing downloaded yet'), findsOneWidget);
  });
}
