#!/bin/bash
set -e
set -o pipefail
set -u
flutter analyze --fatal-warnings
flutter clean
flutter build apk --flavor btgnss -t lib/main.dart
ls -l build/app/outputs/flutter-apk/app-btgnss-release.apk
cp build/app/outputs/flutter-apk/app-btgnss-release.apk app-release.apk
ls -l app-release.apk
echo "BUILD SUCCESS"
