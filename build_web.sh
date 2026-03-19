#!/bin/bash
set -e

echo "=== Building WASM ==="
flutter_rust_bridge_codegen build-web --output web/pkg

echo "=== Copying WASM files ==="
cp rust/web/pkg/pkg/* web/pkg/

echo "=== Running flutter web ==="
flutter run -d chrome -t lib/main_web.dart
