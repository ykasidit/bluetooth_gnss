#!/bin/bash
set -e
set -o pipefail
set -u
flutter analyze --fatal-warnings
flutter clean
flutter build apk --flavor batray -t lib/main_batray.dart
ls -l build/app/outputs/flutter-apk/app-batray-release.apk
cp build/app/outputs/flutter-apk/app-batray-release.apk app-batray-release.apk
ls -l app-batray-release.apk
echo "BUILD BATRAY SUCCESS"
