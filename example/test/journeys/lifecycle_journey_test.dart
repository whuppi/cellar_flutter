// Lifecycle journey — fill the capped cache past its limit, evict on
// demand, watch the oldest objects go, on every device shape.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('lifecycle: overfill cache, evict oldest', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[3]);

      // 6 × 100 KiB = 600 KiB > the 512 KiB cap.
      for (var i = 0; i < 6; i++) {
        await tab.tapOp('add 100 KiB');
        await tab.expectLog('✓ junk added');
      }

      await tab.tapOp('evict now');
      // 600 KiB → oldest evicted until ≤ 512 KiB: exactly one goes.
      await tab.expectLog('✓ eviction pass: 6 → 5 objects');
    });
  });
}
