// AppRobot — boots the example and navigates its tab shell.
//
// App-specific: knows the seven tabs and each tab's marker (a string
// unique to that tab's body, used to confirm the page actually
// switched). Inherits the hardened primitives from the harness Robot.

import 'dart:io';

import 'package:cellar_example/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_path_provider.dart';
import '../harness/memory_disk.dart';
import '../harness/pump_strategies.dart';
import '../harness/robot.dart';

/// Every tab: TabBar label + a marker unique to that tab's body.
const appTabs = <({String label, String marker})>[
  (label: 'Store', marker: 'Write and read'),
  (label: 'Stream', marker: 'writeStream with live progress'),
  (label: 'Partitions', marker: 'Route writes by partition'),
  (label: 'Lifecycle', marker: 'Fill the cache past its cap'),
  (label: 'Encrypt', marker: 'Transparent encryption'),
  (label: 'Materialize', marker: 'A handle the platform understands'),
  (label: 'Custom', marker: 'Bring your own backend'),
];

class AppRobot extends Robot {
  AppRobot(super.tester);

  /// The storage root the launched app writes into (planted per launch).
  late final Directory storageRoot;

  /// Plant a fresh storage root, boot the example, and wait past the
  /// cellar-opening gate until the tab shell is on-stage.
  Future<void> launch() async {
    storageRoot = plantFreshStorageRoot();
    if (!isOnMemoryDisk) {
      // A virtual disk dies with the test; a real one needs cleanup.
      addTearDown(() {
        try {
          storageRoot.deleteSync(recursive: true);
        } on FileSystemException {
          // Best-effort; the OS temp reaper owns leftovers.
        }
      });
    }

    app.main();
    await tester.pump();
    // The cellar-opening gate: on the journeys' memory disk the IO
    // completes as microtasks, so plain pumping is enough.
    await pumpUntil(
      tester,
      () => tester.any(find.text('Store')),
      describe: 'tab shell on-stage after the cellar opens',
    );
  }

  /// The TabBar's own (horizontal) scrollable — the first Scrollable in
  /// the tree, above the body.
  Finder get _tabBar => find.byType(Scrollable).first;

  /// Switch to [tab] and confirm its body is on-stage via its marker.
  Future<void> openTab(({String label, String marker}) tab) {
    return tapTab(
      find.text(tab.label),
      tabBar: _tabBar,
      pageContent: find.textContaining(tab.marker),
    );
  }
}
