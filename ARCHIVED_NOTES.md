# Archived notes (2026-04)

This repository was archived in April 2026. The notes below capture the
last-known-good build environment and a few details a future forker would
otherwise have to rediscover.

## Last-known-good toolchain

- **Flutter SDK:** 3.24.3 (`flutter downgrade v3.24.3`) — must match `pubspec.yaml`
- **Rust:** 1.90 (`rustup install 1.90 && rustup default 1.90`)
- **flutter_rust_bridge_codegen:** 2.11.1 — must match `pubspec.yaml`
- **Android:** minSdk 26, targetSdk 36, compileSdk 36, NDK 27.0.12077973, Java 17
- **Target ABI:** arm64-v8a only

## Final app version on Google Play

Last published version is in `pubspec.yaml` (`version:` field). Format is
`major.minor.patch+buildNumber`.

## Signing

Release builds expect `key.properties` in the **parent** directory of the repo
(i.e. `../key.properties` relative to the project root) with:

```
storeFile=/path/to/keystore.jks
storePassword=...
keyAlias=bluetooth_gnss
keyPassword=...
```

The keystore itself is not in this repo. A forker will need to generate their
own keystore and publish under their own `applicationId`.

## Flutter flavors

Two apps build from this single codebase:

| Flavor   | Entry point              | applicationId                   |
|----------|--------------------------|---------------------------------|
| `btgnss` | `lib/main.dart`          | `com.clearevo.bluetooth_gnss`   |
| `batray` | `lib/main_batray.dart`   | `com.clearevo.batray`           |

Build scripts: `build.sh` / `build_batray.sh`.

## Architecture in one paragraph

Three-language stack: **Dart** (Flutter UI in `lib/`), **Java** (Android
foreground service, Bluetooth RFCOMM, NTRIP in
`android/app/src/main/java/com/clearevo/...`), and **Rust** (NMEA + Qstarz
parsers in `rust/src/`, called from Java via JNI — *not* via
flutter_rust_bridge for the hot parsing path; FRB is only used for a small
`api/simple.rs` surface). Communication between Dart and Java goes over
`MethodChannel` (`com.clearevo.bluetooth_gnss/engine`) and `EventChannel`
(`.../engine_events`, `.../settings_events`).

## Likely first breakage points for a future forker

1. **Google Play `targetSdk` floor** rises every August — bump
   `android/app/build.gradle` and re-test.
2. **Mock location API** behavior on new Android versions. The app sets mocks
   on both `"fused"` and `"gps"` providers via microg's
   `org.microg.gms:play-services-location` (intentionally not Google Play
   Services). If this stops working, that's the most likely root cause.
3. **Bluetooth permission model** changes (Android 12 / 13 / 14 each tightened
   something).
4. **Foreground-service-from-broadcast-receiver** restrictions on Android 12+
   are already worked around by routing intents to `MainActivity` instead of
   `BroadcastReceiver`. See `MainActivity.java` and `Autostart.java`.

## Companion repo

The earlier library extraction at
`https://github.com/ykasidit/libbluetooth_gnss` is also archived as of the
same date.

## License

GPL v2 — fork freely. See `LICENSE` / the README footer.
