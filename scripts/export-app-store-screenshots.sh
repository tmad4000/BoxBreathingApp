#!/bin/bash
set -euo pipefail
: "${1:?Usage: scripts/export-app-store-screenshots.sh SCREENSHOT_DIRECTORY}"
mkdir -p "$1/upload"
for image in "$1"/box-*.png; do
  sips -s format jpeg -s formatOptions best "$image" --out "$1/upload/$(basename "$image" .png).jpg" >/dev/null
done
