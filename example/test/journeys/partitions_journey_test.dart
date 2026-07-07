// Partitions journey — routing, cross-partition copy, wipe, through the
// real UI on every device shape.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('partitions: route, copy across, wipe', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[2]);

      await tab.tapOp('write to main');
      await tab.expectLog('✓ doc/report → main (default)');

      await tab.tapOp('write to cache');
      await tab.expectLog('✓ thumb/report → cache');

      await tab.tapOp('write to scratch');
      await tab.expectLog('✓ tmp/upload → scratch');

      await tab.tapOp('copy main → cache');
      await tab.expectLog('✓ copied doc/report across partitions');

      await tab.tapOp('wipe cache');
      await tab.expectLog('✓ cache wiped — main and scratch untouched');
    });
  });
}
