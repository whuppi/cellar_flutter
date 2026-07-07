// Memory disk — Flutter's own pattern for file IO in widget tests.
//
// Widget tests run under fake time; REAL disk futures only complete
// inside `tester.runAsync`, and runAsync clashes with live animation
// tickers (flutter/flutter#43501 — negative-elapsed assertions). The
// gold solution used by Flutter's own test suites (flutter_tools,
// flutter_test goldens) is to never need runAsync: run the body inside
// `IOOverrides.runZoned` backed by a MemoryFileSystem, so every
// dart:io call the app makes lands on a virtual disk whose operations
// complete as microtasks — flushed by ordinary pumps.
//
// The app and the package under test run UNCHANGED — the swap happens
// at the dart:io boundary. Wrap the ENTIRE journey body (taps
// included): Dart zones are dynamic, so a tap handler runs in the
// caller's zone — only calls made inside the wrapper are redirected.
//
// App-agnostic — part of harness/.

import 'dart:io' as io;

import 'package:file/memory.dart';

/// Run [body] on a fresh in-memory disk.
Future<T> onMemoryDisk<T>(Future<T> Function() body) {
  final fs = MemoryFileSystem.test();
  return io.IOOverrides.runZoned(
    body,
    createDirectory: (p) => fs.directory(p),
    createFile: (p) => fs.file(p),
    createLink: (p) => fs.link(p),
    getCurrentDirectory: () => fs.currentDirectory,
    setCurrentDirectory: (p) => fs.currentDirectory = p,
    getSystemTempDirectory: () => fs.systemTempDirectory,
    stat: (p) => fs.stat(p),
    statSync: (p) => fs.statSync(p),
    fseIdentical: (p1, p2) => fs.identical(p1, p2),
    fseIdenticalSync: (p1, p2) => fs.identicalSync(p1, p2),
    fseGetType: (p, follow) => fs.type(p, followLinks: follow),
    fseGetTypeSync: (p, follow) => fs.typeSync(p, followLinks: follow),
    fsWatchIsSupported: () => fs.isWatchSupported,
  );
}

/// True while running on the virtual disk — lets support code skip
/// real-FS-only concerns (temp cleanup, xattrs).
bool get isOnMemoryDisk => io.IOOverrides.current != null;
