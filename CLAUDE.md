# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bluetooth GNSS is an Android app (Flutter + Rust + Java) that connects to external Bluetooth GPS/GNSS receivers and provides location data to Android via mock location providers. Published on Google Play as [Bluetooth GNSS](https://play.google.com/store/apps/details?id=com.clearevo.bluetooth_gnss). Licensed under GPL v2.

## Build Commands

```bash
# Install dependencies
flutter pub get

# Analyze (strict mode: --fatal-warnings)
flutter analyze --fatal-warnings

# Build release APK
flutter build apk

# Full release build (analyze + clean + build + copy APK)
./build.sh

# Debug run on connected device
flutter run

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
- Minification is disabled in release builds (prevents runtime crashes)
- Target ABI: arm64-v8a only

## Key Build Notes

- Android: minSdk 26, targetSdk 36, compileSdk 36, NDK 27.0.12077973, Java 17
- Version format: `major.minor.patch+buildNumber` (e.g., 3.0.5+305) in `pubspec.yaml`
- `tag.py` handles git tagging for releases
