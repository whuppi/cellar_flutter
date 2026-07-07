// Store journey — write / read / head / typed-error, through the real
// UI against a real temp-dir filesystem, on every device shape.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('store: write, read, head, typed error', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[0]);

      await tab.tapOp('write');
      await tab.expectLog('✓ wrote notes/hello');

      await tab.tapOp('read');
      await tab.expectLog('✓ read notes/hello → "Hello from cellar!"');

      await tab.tapOp('head');
      await tab.expectLog('✓ head notes/hello → 18 B, text/plain');

      // Typed errors: the missing-key read surfaces FileNotFoundError.
      await tab.tapOp('read missing key');
      await tab.expectLog('✓ typed error caught');
    });
  });
}
