// Stream journey — 4 MiB in with progress, streamed out, range-read,
// through the real UI on every device shape.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('stream: write with progress, read, range', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[1]);

      await tab.tapOp('stream 4 MiB in');
      await tab.expectLog('✓ streamed 4.00 MB → big/lorem');

      await tab.tapOp('stream out + count');
      await tab.expectLog('✓ readStream → 4.00 MB');

      await tab.tapOp('readRange middle 32 B');
      await tab.expectLog('✓ readRange @2.00 MB');
    });
  });
}
