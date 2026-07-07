import 'package:cellar/cellar.dart';
import 'package:path_provider/path_provider.dart';

/// Resolve [StorageRoots] from path_provider — the official ask on
/// every native platform (this is what makes Android work: its app
/// directories are only knowable by asking the OS).
Future<StorageRoots?> resolveFlutterRoots() async {
  final support = await getApplicationSupportDirectory();
  final cache = await getApplicationCacheDirectory();
  return StorageRoots(support: support.path, cache: cache.path);
}
