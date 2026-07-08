# ═══════════════════════════════════════════════════════════════════
# SDK resolution
#
# Uses fvm by default (.fvmrc pins the version). Contributors without
# fvm can override:  make check DART=dart FLUTTER=flutter
# ═══════════════════════════════════════════════════════════════════

DART    ?= fvm dart
FLUTTER ?= fvm flutter
TEST_RESULTS_DIR ?= test-results
TIMEOUT := $(if $(CI),--timeout=30x,)
VERBOSE := $(if $(CI),--verbose,)

.PHONY: check hooks \
        analyze analyze-floor format lint-shell platforms test \
        test-example test-example-matrix test-example-macos test-example-device \
        test-example-android test-example-ios test-example-linux \
        test-example-windows test-example-web \
        verify-android verify-ios verify-macos verify-linux \
        verify-windows verify-web \
        clean

# ═══════════════════════════════════════════════════════════════════
# § 1 — Gate
#
# make check    Full local gate before PR.
# make hooks    Activate the family repo's git hooks. Run once after
#               cloning — they stay dormant otherwise. Idempotent.
# ═══════════════════════════════════════════════════════════════════

check: format analyze analyze-floor lint-shell platforms test test-example-matrix

hooks:
	@git config core.hooksPath .githooks
	@echo "✓ git hooks active (core.hooksPath → .githooks)"

# ═══════════════════════════════════════════════════════════════════
# § 2 — Analyze
#
# make format   Formatter in check mode — fails on unformatted files.
# make analyze  dart analyze --fatal-infos over the package + example.
# ═══════════════════════════════════════════════════════════════════

format:
	$(DART) format --output=none --set-exit-if-changed .

analyze:
	@DART="$(DART)" FLUTTER="$(FLUTTER)" bash tool/analyze_core.sh

# Floor-analyze: prove the pubspec's LOWER bounds actually work, then
# restore the lockfile so the working tree is untouched.
analyze-floor:
	@cp pubspec.lock .pubspec.lock.floor-backup
	$(FLUTTER) pub downgrade
	$(DART) analyze lib
	@mv .pubspec.lock.floor-backup pubspec.lock
	@$(FLUTTER) pub get >/dev/null
	@echo "✓ floor analyze clean (lockfile restored)"

# pana's platform attribution — all six targets must survive the
# conditional-import walk (the stub default is what makes web attribute).
# pana resolves deps as pub.dev would: dependency_overrides are ignored,
# and the hosted `cellar` dep can't solve until the core is published.
# For the gate's duration the dep is swapped to the submodule path (the
# snapshot carries `cellar/`), then the pubspec is restored.
platforms:
	@cp pubspec.yaml .pubspec.yaml.platforms-backup
	@python3 -c "import pathlib; p = pathlib.Path('pubspec.yaml'); s = p.read_text(); s = s.replace('  cellar: ^1.0.0', '  cellar:\n    path: cellar'); s = s.split('\ndependency_overrides:')[0]; p.write_text(s)"
	@DART="$(DART)" EXPECTED_PLATFORMS="android ios linux macos windows web" bash tool/platforms_gate.sh; \
	rc=$$?; mv .pubspec.yaml.platforms-backup pubspec.yaml; exit $$rc

lint-shell:
	@bash tool/lint_shell.sh

# ═══════════════════════════════════════════════════════════════════
# § 3 — Test
#
# make test     The package's own tests (openCellar root resolution).
# ═══════════════════════════════════════════════════════════════════

test:
	@echo "=== cellar_flutter: package tests ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	$(FLUTTER) test $(VERBOSE) $(TIMEOUT) --file-reporter json:$(TEST_RESULTS_DIR)/unit.json

# ═══════════════════════════════════════════════════════════════════
# § 3b — Example tests
#
# make test-example-matrix   Host-VM journeys: the example UI driven end
#                            to end through the real storage stack on an
#                            in-memory disk, across every device profile.
#                            No device needed — part of check.
# make test-example-macos    Integration smoke on macOS (real filesystem
#                            through the real path_provider).
# make test-example-device   Integration smoke on DEVICE=<id>.
#
# make test-example-<plat>   Integration smoke on one real target
#                            (android / ios / linux / windows / web). The
#                            per-platform CI matrix (full-test) runs
#                            these. Android + iOS run on the booted
#                            emulator/simulator (no -d); the Android
#                            report lands at test-results/int-android.json,
#                            which the emulator teardown-watchdog
#                            reconciles.
# make verify-<plat>         Release build of the example — proves both
#                            packages build and link on that target.
# ═══════════════════════════════════════════════════════════════════

test-example: test-example-matrix test-example-macos

test-example-matrix:
	@echo "=== Example: journey matrix (host VM, every device profile) ==="
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) test/journeys

test-example-macos:
	@echo "=== Example: integration smoke on macOS ==="
	cd example && $(FLUTTER) test $(TIMEOUT) integration_test/cellar_smoke_test.dart -d macos

test-example-device:
	@echo "=== Example: integration smoke on device=$(DEVICE) ==="
	cd example && $(FLUTTER) test $(TIMEOUT) integration_test/cellar_smoke_test.dart -d $(DEVICE)

# Android + iOS run on the connected/booted device — no -d. CI boots the
# emulator/simulator via the make-target capabilities. The Android JSON
# report is what the emulator watchdog's reconciler reads.
test-example-android:
	@echo "=== Example: Android ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/cellar_smoke_test.dart --file-reporter json:../$(TEST_RESULTS_DIR)/int-android.json

test-example-ios:
	@echo "=== Example: iOS ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/cellar_smoke_test.dart --file-reporter json:../$(TEST_RESULTS_DIR)/int-ios.json

test-example-linux:
	@echo "=== Example: Linux ==="
	$(call ensure_gtk)
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/cellar_smoke_test.dart -d linux --file-reporter json:../$(TEST_RESULTS_DIR)/int-linux.json

test-example-windows:
	@echo "=== Example: Windows ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/cellar_smoke_test.dart -d windows --file-reporter json:../$(TEST_RESULTS_DIR)/int-windows.json

# Web integration runs through flutter drive (-d web-server) with a single
# Chrome managed by chromedriver — the same shape as the workspace gold
# packages' web path, minus WASM threading modes (cellar has none). One
# shell so the background chromedriver PID survives to the cleanup.
test-example-web:
	@echo "=== Example: Web (integration smoke via flutter drive) ==="
	@chromedriver --port=4444 >/dev/null 2>&1 & \
	CD_PID=$$!; \
	sleep 2; \
	( cd example && $(FLUTTER) drive \
	    --driver=test_driver/integration_test.dart \
	    --target=integration_test/cellar_smoke_test.dart \
	    -d web-server \
	    --browser-name=chrome \
	    --driver-port=4444 \
	    --web-browser-flag=--no-sandbox ); \
	rc=$$?; \
	kill $$CD_PID 2>/dev/null || true; \
	exit $$rc

# ── Verify: release builds of the example ──
verify-android:
	@echo "=== Verify: Android ==="
	cd example && $(FLUTTER) build apk --release $(VERBOSE)

verify-ios:
	@echo "=== Verify: iOS ==="
	cd example && $(FLUTTER) build ios --release --no-codesign $(VERBOSE)

verify-macos:
	@echo "=== Verify: macOS ==="
	cd example && $(FLUTTER) build macos --release $(VERBOSE)

verify-linux:
	@echo "=== Verify: Linux ==="
	$(call ensure_gtk)
	cd example && $(FLUTTER) build linux --release $(VERBOSE)

verify-windows:
	@echo "=== Verify: Windows ==="
	cd example && $(FLUTTER) build windows --release $(VERBOSE)

verify-web:
	@echo "=== Verify: Web (dart2js + dart2wasm) ==="
	@FLUTTER="$(FLUTTER)" bash tool/verify_web_gate.sh

# ═══════════════════════════════════════════════════════════════════
# § 3c — Build helpers
# ═══════════════════════════════════════════════════════════════════

# Linux desktop builds need GTK 3. Present → no-op. Missing → install on
# CI, instruct locally.
define ensure_gtk
	@command -v pkg-config >/dev/null && pkg-config --exists gtk+-3.0 || { \
		if [ -n "$$CI" ]; then sudo apt-get update -qq && sudo apt-get install -y -qq ninja-build libgtk-3-dev; \
		else echo "Error: libgtk-3-dev not found. Run: sudo apt-get install -y ninja-build libgtk-3-dev"; exit 1; fi; }
endef

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	$(FLUTTER) clean
	rm -rf $(TEST_RESULTS_DIR)
