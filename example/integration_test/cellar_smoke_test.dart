// Integration smoke — the example's cellar exercised on a REAL platform.
//
// Runs on real devices (Android/iOS), desktop (macOS/Windows/Linux), and
// web (via flutter drive — see test_driver/). This is where the
// UNPLANTED path runs: openCellar asks the real path_provider for the
// app's storage roots, so the one seam host-VM journeys fake is proven
// here on every platform — including Android, whose roots are only
// knowable this way.
//
// Hardcoded data only — no pickers, no permissions, same on every target.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cellar/cellar_lowlevel.dart';
import 'package:cellar_flutter/cellar_flutter.dart';
import 'package:cellar_example/main.dart'
    show DemoEncryptor, DemoKeyResolver, DemoMemoryBackend, tinyPng;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/backup_exclusion_check.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every API surface, real platform storage', (tester) async {
    // ── The unplanted path: openCellar asks the REAL path_provider ──
    final cellar = await openCellar(
      name: 'cellar_smoke_${DateTime.now().millisecondsSinceEpoch}',
      partitions: {
        'main': const PartitionConfig(),
        'cache': const PartitionConfig(
          lifecycle: Lifecycle(maxBytes: 1024, runInterval: Duration(hours: 1)),
          osBackup: false,
        ),
      },
      defaultPartition: 'main',
    );

    try {
      // Write / read / head / typed errors.
      final body = Uint8List.fromList(utf8.encode('smoke'));
      await cellar.write('doc/a', body, contentType: 'text/plain');
      expect(await cellar.read('doc/a'), body);
      expect((await cellar.head('doc/a'))!.contentType, 'text/plain');
      await expectLater(
        cellar.read('missing'),
        throwsA(isA<FileNotFoundError>()),
      );

      // Streaming + range.
      final big = Uint8List.fromList(List<int>.filled(256 * 1024, 7));
      await cellar.writeStream('doc/big', Stream.value(big));
      expect(
        await cellar.readRange('doc/big', start: 1000, length: 4),
        Uint8List.fromList([7, 7, 7, 7]),
      );

      // Partitions: route, copy across, wipe.
      await cellar.write('t/x', body, partition: 'cache');
      await cellar.copyAcrossPartitions(
        fromPartition: 'cache',
        fromKey: 't/x',
        toPartition: 'main',
        toKey: 't/x',
      );
      expect(await cellar.exists('t/x'), isTrue);
      await cellar.wipePartition('cache');
      expect(await cellar.exists('t/x', partition: 'cache'), isFalse);

      // ── iOS: backup exclusion observed on the real runtime ──
      // The cache partition opted out (osBackup: false); the check asks
      // the OS's own resource layer whether the partition directory
      // carries NSURLIsExcludedFromBackupKey. Null = not applicable on
      // this platform (covered by the macOS tmutil observation and the
      // VM CF round-trip test instead).
      await cellar.write('probe', body, partition: 'cache');
      final probeHandle = await cellar.materialize('probe', partition: 'cache');
      final excluded = await observeBackupExclusion(probeHandle.localPath);
      if (excluded != null) {
        expect(
          excluded,
          isTrue,
          reason:
              'osBackup:false partition must carry the exclusion '
              'on the real iOS runtime',
        );
      }
      await probeHandle.release();

      // Lifecycle eviction on the real store.
      await cellar.write('junk/1', Uint8List(2048), partition: 'cache');
      await cellar.runLifecycleNow();
      expect(
        await cellar.exists('junk/1', partition: 'cache'),
        isFalse,
        reason: '2 KiB object over a 1 KiB cap must evict',
      );

      // Materialize: a handle the platform understands.
      await cellar.write('media/px', tinyPng, contentType: 'image/png');
      final handle = await cellar.materialize('media/px');
      expect(handle.localPath, isNotEmpty);
      await handle.release();
    } finally {
      await cellar.wipePartition('main');
      await cellar.close();
    }
  });

  testWidgets('encrypted stack round-trips on this platform', (tester) async {
    final base = DemoMemoryBackend();
    final vault = Cellar.withBackends({
      'vault': EncryptedBackend(
        inner: base,
        encryptor: DemoEncryptor(),
        keyResolver: DemoKeyResolver(),
      ),
    }, defaultPartition: 'vault');
    await vault.open();
    try {
      final secret = Uint8List.fromList(utf8.encode('smoke secret'));
      await vault.write('s', secret, encrypt: true);
      expect(await vault.read('s'), secret);
      // At rest it is ciphertext, not the plaintext.
      final raw = base.rawBytes(base.rawKeys.single)!;
      expect(utf8.decode(raw, allowMalformed: true), isNot(contains('smoke')));
    } finally {
      await vault.close();
      await base.dispose();
    }
  });
}
