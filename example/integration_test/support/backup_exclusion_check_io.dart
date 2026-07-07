import 'dart:io';

// White-box import — the read-back lives on the OS seam, not the
// public surface. Test-only.
import 'package:cellar/src/backends/file_system/os/ios_file_system_os.dart';

/// iOS only: recover the partition's directory from a materialized
/// object's real path (its ancestor named [partition]) and ask the OS's
/// own resource layer — the state the backup engine consults — whether
/// it carries the exclusion. Returns null where the question doesn't
/// apply (non-iOS platforms).
Future<bool?> observeBackupExclusion(
  String materializedPath, {
  String partition = 'cache',
}) async {
  if (!Platform.isIOS) return null;
  var dir = Directory(materializedPath).parent;
  while (dir.path != dir.parent.path &&
      dir.uri.pathSegments.where((s) => s.isNotEmpty).last != partition) {
    dir = dir.parent;
  }
  return IosFileSystemOs().isExcludedFromBackup(dir.path);
}
