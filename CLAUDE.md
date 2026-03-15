# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo builds two Android apps from one codebase using Flutter flavors:
- **Bluetooth GNSS** — connects to external Bluetooth GPS/GNSS receivers and provides location data to Android via mock location providers. Published on [Google Play](https://play.google.com/store/apps/details?id=com.clearevo.bluetooth_gnss). Entry point: `lib/main.dart`
- **BatRay** — (in development). Entry point: `lib/main_batray.dart`

Both share the same Flutter + Rust + Java three-language stack and `libbluetooth_gnss_service`. Licensed under GPL v2.

## Build Commands

The project uses **Flutter flavors** to build two apps from one codebase:
- **btgnss** — Bluetooth GNSS (applicationId: `com.clearevo.bluetooth_gnss`)
- **batray** — BatRay (applicationId: `com.clearevo.batray`)

```bash
# Install dependencies
flutter pub get

# Analyze (strict mode: --fatal-warnings)
flutter analyze --fatal-warnings

# Build Bluetooth GNSS (btgnss flavor)
flutter build apk --flavor btgnss -t lib/main.dart
./build.sh                        # full release: analyze + clean + build + copy APK

# Build BatRay (batray flavor)
flutter build apk --flavor batray -t lib/main_batray.dart
./build_batray.sh                 # full release: analyze + clean + build + copy APK

# Debug run
flutter run --flavor btgnss -t lib/main.dart
flutter run --flavor batray -t lib/main_batray.dart

# Release build + push
./build_and_push_release.sh       # btgnss
./build_and_push_release_batray.sh  # batray

# Regenerate Rust FFI bindings (after modifying rust code)
flutter_rust_bridge_codegen generate
# May need to restore main.dart afterwards:
git checkout lib/main.dart

# Regenerate app icons
dart run flutter_launcher_icons
```

## Tests

```bash
# Run Dart/Flutter tests
flutter test

# Run a single test file
flutter test test/some_test.dart

# Java unit tests: open the `android/` subfolder as a separate Android Studio project,
# then navigate to libecodroidgnss_parse > java > (test) and run tests from there.
```

Test coverage is minimal — `test/widget_test.dart` and `test/some_test.dart` exist.

## Required Toolchain

- **Flutter SDK**: must match version in `pubspec.yaml` (currently 3.24.3) — use `flutter downgrade v3.24.3`
- **Rust**: `rustup install 1.90 && rustup default 1.90`
- **flutter_rust_bridge_codegen**: version must match `pubspec.yaml` (currently 2.11.1)
- **Android signing**: `key.properties` file in parent directory (`../key.properties`) with keystore path and credentials

## Architecture

### Three-Language Stack

```
┌──────────────────────────────────────────┐
│  Flutter/Dart (UI layer)                 │
│  lib/*.dart                              │
├──────────────────────────────────────────┤
│  Platform Channels (MethodChannel/Event) │
├────────────────────┬─────────────────────┤
│  Java (Android)    │  Rust (via JNI)     │
│  android/app/src/  │  rust/src/          │
│  Service, BT mgmt  │  GNSS parsing       │
└────────────────────┴─────────────────────┘
```

**Dart** (`lib/`): UI screens, connection state machine, settings. Entry point is `main.dart`, main navigation in `home.dart` (tabs: Connect, Map, Settings, Messages).

**Java** (`android/app/src/main/java/`): Two packages:
- `com.clearevo.bluetooth_gnss` — `MainActivity.java` (platform channel setup, method/event handling), `Autostart.java`, `StartConnectionReceiver.java`
- `com.clearevo.libbluetooth_gnss_service` — `bluetooth_gnss_service.java` (core foreground service), `rfcomm_conn_mgr.java` (Bluetooth RFCOMM), `ntrip_conn_mgr.java` (NTRIP RTK corrections), I/O threads, logging

**Rust** (`rust/src/`): Performance-critical GNSS parsing called from Java via JNI (not through flutter_rust_bridge for the main parsing path):
- `lib.rs` — JNI entry points (`NativeParser.parse()`, `NativeParser.reset()`, `NativeParser.parse_qstarz_pkt()`)
- `nmea_parser.rs` — NMEA 0183 sentences (GGA, GSA, RMC, VTG, GLL, $PUBX), multi-constellation
- `qstarz_parser.rs` — Qstarz proprietary binary protocol
- `gnss_parser.rs` — Parser orchestration
- `api/simple.rs` — flutter_rust_bridge FFI interface (basic functions)

### Platform Communication

- **MethodChannel** `com.clearevo.bluetooth_gnss/engine`: Dart→Java request-response (connect, get_bd_map, get_mountpoint_list, etc.)
- **EventChannel** `com.clearevo.bluetooth_gnss/engine_events`: Java→Dart streaming (live GNSS data, mock location timestamps, device messages)
- **EventChannel** `com.clearevo.bluetooth_gnss/settings_events`: Settings change notifications

### Connection State Machine

`ConnectState` enum drives UI: Loading → PendingRequirements → ReadyToConnect → Connecting → Connected. Each state has a corresponding screen widget (`connect_screen_idle.dart`, `connect_screen_connecting.dart`, `connect_screen_connected.dart`).

### Generated Code

`lib/src/rust/` contains auto-generated flutter_rust_bridge bindings — do not edit manually. Regenerate with `flutter_rust_bridge_codegen generate`.

## Code Style

- Analysis uses `flutter_lints` with `strict-casts: true` and `strict-raw-types: true`
- Snake_case identifiers are allowed (non_constant_identifier_names and constant_identifier_names disabled)
- Java code uses snake_case for class names (e.g., `bluetooth_gnss_service`, `rfcomm_conn_mgr`)
- Minification is disabled in release builds (prevents runtime crashes with Rust/JNI)
- Target ABI: arm64-v8a only
- Android Gradle lint: `abortOnError = true`, `warningsAsErrors = true`

### Tasker/External Intent Support

External apps (Tasker, Automate, etc.) can trigger connect/disconnect via intents. On Android 12+ (API 31+), intents must target the **Activity** (not Broadcast Receiver) because foreground service starts from broadcast receivers are restricted.

- **Intent actions**: `bluetooth.CONNECT`, `bluetooth.DISCONNECT`, `tasker.MOCK`
- **MainActivity** handles intents via `onNewIntent()` (singleTop) and `configureFlutterEngine()` (fresh launch)
- **BroadcastReceivers** (`StartConnectionReceiver`, `Autostart`) still exist for backward compatibility — on Android 12+ they forward to MainActivity
- **BOOT_COMPLETED** is exempt from the restriction and starts the service directly via `Autostart`
- Connection parameters are loaded from `last_connect_dev.json` (saved by `Util.save_connect_args()` on each connect from the app)
- `bluetooth.CONNECT` supports a `config` extra with JSON overrides for keys in `BT_CONNECT_ARGS`, `BT_MOCK_ARGS`, `NTRIP_CONNECT_ARGS`

### Mock Location Providers

Uses microg's `play-services-location` (`org.microg.gms:play-services-location`) — not Google Play Services. Sets mock location on both `"fused"` and `"gps"` providers.

## Git Workflow

- Use `git pull` and `git push` — **never rebase**. Exact commit history and line-by-line authorship must be preserved.

## Key Build Notes

- Android: minSdk 26, targetSdk 36, compileSdk 36, NDK 27.0.12077973, Java 17
- Version format: `major.minor.patch+buildNumber` (e.g., 3.0.5+305) in `pubspec.yaml`
- `tag.py` handles git tagging for releases
