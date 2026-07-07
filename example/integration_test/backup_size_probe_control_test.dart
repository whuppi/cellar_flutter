// CONTROL variant of the backup-size probe: the same 8 MiB goes into the
// KEPT (backed-up) partition. If iCloud's backup list shows the app at
// ~8 MB with this variant, dev-installed apps demonstrably participate
// in iCloud backup — proving the excluded variant's absence was the
// exclusion working. Not part of any suite; uninstall the app to clean.
import 'dart:typed_data';

import 'package:cellar_flutter/cellar_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plant CONTROL data — bulk in the backed-up partition', (
    tester,
  ) async {
    final cellar = await openCellar(
      name: 'backup_probe',
      partitions: {
        'kept': const PartitionConfig(),
        'excluded': const PartitionConfig(osBackup: false),
      },
      defaultPartition: 'kept',
    );

    for (var i = 0; i < 8; i++) {
      await cellar.write(
        'bulk_kept/$i',
        Uint8List.fromList(List<int>.filled(1024 * 1024, i)),
        partition: 'kept',
      );
    }
    await cellar.close();
  });
}
