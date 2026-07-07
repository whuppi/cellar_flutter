// Custom-backend journey — a user-implemented StorageBackend behind the
// full Cellar facade, with two tenant-scoped cellars proving keyPrefix
// isolation at the raw-key level. Every device shape.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('custom backend: tenant isolation', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[6]);

      await tab.tapOp('write as alice');
      await tab.expectLog('✓ alice wrote photos/cat');

      await tab.tapOp('list as alice');
      await tab.expectLog('✓ alice sees: [photos/cat]');

      await tab.tapOp('list as bob');
      await tab.expectLog('✓ bob sees: []');

      await tab.tapOp('peek raw backend keys');
      await tab.expectLog('user/alice/photos/cat');
    });
  });
}
