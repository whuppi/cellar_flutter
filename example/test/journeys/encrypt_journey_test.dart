// Encrypt journey — write a secret, read it back, see ciphertext at
// rest, tamper a byte and watch MAC verification catch it. Every device
// shape.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';

void main() {
  testJourneyAcrossDevices('encrypt: round-trip, raw peek, tamper', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      final tab = TabRobot(tester);
      await app.launch();
      await app.openTab(appTabs[4]);

      await tab.tapOp('write secret');
      await tab.expectLog('✓ wrote diary/today (encrypted)');

      await tab.tapOp('read back');
      await tab.expectLog('✓ decrypted read → "my secret diary entry');

      await tab.tapOp('peek RAW stored bytes');
      await tab.expectLog('of ciphertext');

      await tab.tapOp('tamper one byte → read');
      await tab.expectLog('✓ MAC verification caught the tamper');
    });
  });
}
