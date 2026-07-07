// One-shot probe for the MANUAL iCloud backup-size observation (the
// optional cherry in cellar's roadmap; recipe in cellar/docs/UPDATING.md
// S7). Deliberately LEAVES DATA on the device — not part of any suite;
// CI runs cellar_smoke_test.dart only. Clean up by uninstalling the app.
//
//   kept/     control — default config, iCloud backs it up (~16 KiB)
//   excluded/ osBackup: false — must NOT appear in the backup (~8 MiB)
import 'dart:typed_data';

import 'package:cellar_flutter/cellar_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/backup_exclusion_check.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plant backup-size probe data', (tester) async {
    final cellar = await openCellar(
      name: 'backup_probe',
      partitions: {
        'kept': const PartitionConfig(),
        'excluded': const PartitionConfig(osBackup: false),
      },
      defaultPartition: 'kept',
    );

    await cellar.write('control', Uint8List(16 * 1024), partition: 'kept');
    for (var i = 0; i < 8; i++) {
      await cellar.write(
        'bulk/$i',
        Uint8List.fromList(List<int>.filled(1024 * 1024, i)),
        partition: 'excluded',
      );
    }

    // Sanity on the way out: the OS resource layer must report the
    // exclusion before we hand this to the human step.
    final handle = await cellar.materialize('bulk/0', partition: 'excluded');
    final excluded = await observeBackupExclusion(
      handle.localPath,
      partition: 'excluded',
    );
    await handle.release();
    expect(excluded, isTrue);

    // NO wipe, NO delete — the data must survive for the backup cycle.
    await cellar.close();
  });
}
