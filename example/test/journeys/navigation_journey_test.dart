// Navigation journey — every tab reachable + showing its surface, on
// every device shape.
//
// Runs host-VM via the device matrix. Because the matrix includes a
// viewport smaller than any CI emulator, a tab that clips off-screen (or
// a tap that misses on a narrow bar) fails HERE, locally, on every
// `flutter test` — never first in CI.

import 'package:cellar_example_test_support/cellar_example_test_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testJourneyAcrossDevices('navigation: every tab opens', (
    tester,
    device,
  ) async {
    // The whole body (taps included) runs on the virtual disk —
    // zones are dynamic, so only calls made inside are redirected.
    await onMemoryDisk(() async {
      final app = AppRobot(tester);
      await app.launch();

      for (final tab in appTabs) {
        await app.openTab(tab);
        app.expectVisible(
          find.textContaining(tab.marker),
          reason: '${tab.label} body not shown on $device',
        );
      }
    });
  });
}
