import 'package:cellar/cellar.dart';

/// Neutral default target — real builds always take the native or web
/// branch of the conditional import.
Future<StorageRoots?> resolveFlutterRoots() =>
    throw UnsupportedError('cellar_flutter: unsupported platform');
