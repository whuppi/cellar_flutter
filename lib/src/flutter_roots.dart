// Conditional switch for the path_provider glue. The stub is the
// DEFAULT target so pub.dev's analyzer attributes every platform;
// native gets the real resolution; web needs none (IndexedDB).
export 'flutter_roots_stub.dart'
    if (dart.library.io) 'flutter_roots_native.dart'
    if (dart.library.js_interop) 'flutter_roots_web.dart';
