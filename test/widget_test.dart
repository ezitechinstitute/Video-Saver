// Smoke tests for the VideoSaver app shell.

import 'package:flutter_test/flutter_test.dart';

import 'package:ezi_download/main.dart';

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
}
