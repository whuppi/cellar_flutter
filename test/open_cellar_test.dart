import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cellar_flutter/cellar_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Answers path_provider's root questions with a temp directory — the
/// platform side doesn't exist on the host VM.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openCellar resolves roots, opens, and round-trips', () async {
    final root = Directory.systemTemp.createTempSync('cellar_flutter_');
    addTearDown(() => root.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(root.path);

    final cellar = await openCellar(name: 'open_cellar_test');
    addTearDown(cellar.close);

    final bytes = Uint8List.fromList(utf8.encode('hello'));
    await cellar.write('a/b', bytes);
    expect(await cellar.read('a/b'), bytes);

    // The resolved SUPPORT root is where the default partition lands —
    // proof the path_provider answer was actually used.
    final landed = Directory(
      '${root.path}/support/open_cellar_test',
    ).existsSync();
    expect(landed, isTrue, reason: 'storage must land under the fake root');
  });

  test('osManaged partitions land under the CACHE root', () async {
    final root = Directory.systemTemp.createTempSync('cellar_flutter_');
    addTearDown(() => root.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(root.path);

    final cellar = await openCellar(
      name: 'roots_split_test',
      partitions: {
        'main': const PartitionConfig(),
        'cache': const PartitionConfig(lifecycle: Lifecycle.cache()),
      },
      defaultPartition: 'main',
    );
    addTearDown(cellar.close);

    await cellar.write('x', Uint8List(1), partition: 'cache');
    expect(
      Directory('${root.path}/cache/roots_split_test').existsSync(),
      isTrue,
      reason: 'osManaged partition must use the cache root',
    );
  });
}
