// The one planted answer host-VM journeys need.
//
// The example app's first act is asking path_provider "which folder
// belongs to this app?" — a question answered by platform code that
// only exists inside a real installed app. On the host VM there is no
// platform side, so journeys plant the answer: a fresh temp directory
// per launch. Everything downstream of the answer is real — real files,
// real bytes, the real package. The unplanted path is proven by the
// on-device smoke suite (integration_test/).

import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Answers path_provider's questions with subdirectories of [root].
///
/// EXTENDS (not implements) the platform interface, so the platform
/// token verification passes without the test-only mock mixin — this
/// class lives in a support package's lib/, where that mixin is
/// off-limits by its own visibility annotation.
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';

  @override
  Future<String?> getApplicationDocumentsPath() async => '$root/documents';
}

/// Create a fresh storage root and plant it as the platform answer.
/// Returns the root so a test can inspect what the app wrote.
Directory plantFreshStorageRoot() {
  final root = Directory.systemTemp.createTempSync('cellar_journey_');
  PathProviderPlatform.instance = FakePathProvider(root.path);
  return root;
}
