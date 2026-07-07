// Materialize journey — store a PNG, get a platform-local handle,
// release it. Every device shape. (On the host VM the handle is a real
// file path; the Blob-URL variant is proven by the web smoke.)

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('materialize: handle out, release', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[5]);

      await tab.tapOp('store PNG + materialize');
      await tab.expectLog('✓ handle:');
      await tab.expectLog('a real file path');

      await tab.tapOp('release');
      await tab.expectLog('✓ released');
    });
  });
}
