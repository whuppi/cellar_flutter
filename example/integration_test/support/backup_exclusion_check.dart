// Conditional switch: the observation needs dart:ffi + dart:io, which
// the smoke's web leg can't compile — the stub answers "not
// applicable" there.
export 'backup_exclusion_check_stub.dart'
    if (dart.library.io) 'backup_exclusion_check_io.dart';
