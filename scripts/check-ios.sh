#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${1:?Usage: scripts/check-ios.sh DEVICE_UUID}"
flutter pub get --offline
flutter analyze
flutter test --reporter expanded
flutter test integration_test/native_test.dart -d "$1" --no-pub
