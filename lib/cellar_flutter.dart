/// The Flutter front door for `package:cellar`.
///
/// `openCellar` resolves the platform storage roots (via path_provider
/// on native; web uses IndexedDB and needs none) and returns an opened
/// `Cellar` — one identical call on every platform. The full cellar API
/// is re-exported, so this is the only import a Flutter app needs.
library;

export 'package:cellar/cellar.dart';

export 'src/open_cellar.dart';
