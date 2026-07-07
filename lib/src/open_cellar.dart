import 'package:cellar/cellar.dart';

import 'flutter_roots.dart';

/// Open a [Cellar] the Flutter way — one identical call on iOS,
/// Android, macOS, Windows, Linux, and web.
///
/// Resolves the platform storage roots via path_provider on native
/// (Android's directories are only knowable by asking the OS); web
/// stores in IndexedDB and needs none. Constructs the cellar, awaits
/// [Cellar.open], and returns it ready to use:
///
/// ```dart
/// final cellar = await openCellar(name: 'my_app');
/// await cellar.write('notes/hello', bytes);
/// ```
///
/// Parameters mirror the [Cellar] default constructor. Call
/// [Cellar.close] when done (app shutdown / test teardown).
Future<Cellar> openCellar({
  required String name,
  Map<String, PartitionConfig>? partitions,
  String defaultPartition = defaultPartitionName,
  String? keyPrefix,
  CellarEncryption? encryption,
  EvictionErrorCallback? onEvictionError,
}) async {
  final cellar = Cellar(
    name: name,
    partitions: partitions,
    defaultPartition: defaultPartition,
    keyPrefix: keyPrefix,
    encryption: encryption,
    onEvictionError: onEvictionError,
    roots: await resolveFlutterRoots(),
  );
  await cellar.open();
  return cellar;
}
