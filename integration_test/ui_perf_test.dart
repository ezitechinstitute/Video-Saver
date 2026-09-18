// Frame timings for the screens people spend time on.
//
// Run in profile mode against a device, not in debug, or the numbers mean
// nothing:
//
//   flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/ui_perf_test.dart
//
// The frame summary lands in build/integration_response_data.json.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ezi_download/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Draw every frame as the app would, not only the ones the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('home, downloads and help screens', (tester) async {
    await tester.pumpWidget(const EziDownloadApp(onboardingSeen: true));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await binding.watchPerformance(() async {
      final scroll = find.byType(Scrollable).first;

      for (var i = 0; i < 4; i++) {
        await tester.fling(scroll, const Offset(0, -600), 2500);
        await tester.pumpAndSettle();
        await tester.fling(scroll, const Offset(0, 600), 2500);
        await tester.pumpAndSettle();
      }

      for (final icon in [
        Icons.download_done_rounded,
        Icons.help_outline_rounded,
      ]) {
        await tester.tap(find.byIcon(icon).first);
        await tester.pumpAndSettle();

        final inner = find.byType(Scrollable);
        if (inner.evaluate().isNotEmpty) {
          await tester.fling(inner.last, const Offset(0, -600), 2500);
          await tester.pumpAndSettle();
        }

        // The screens draw their own back arrow, so pop directly.
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
    }, reportKey: 'ui_perf');
  });
}
