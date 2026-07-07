/// UI-test harness + robots for the cellar example app.
///
/// `harness/` is app-agnostic (copied from the workspace gold package —
/// robot base, device matrix, pump strategies). `robots/` and `fakes/`
/// know this app: its tabs, its op buttons, its log panes, and the one
/// platform answer host-VM journeys must plant.
library;

export 'src/fakes/fake_path_provider.dart';
export 'src/harness/device_matrix.dart';
export 'src/harness/device_profiles.dart';
export 'src/harness/pump_strategies.dart';
export 'src/harness/memory_disk.dart';
export 'src/harness/robot.dart';
export 'src/robots/app_robot.dart';
export 'src/robots/tab_robot.dart';
