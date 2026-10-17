#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /tmp/promptvault-flutter
  export PATH="/tmp/promptvault-flutter/bin:$PATH"
fi
node tools/bootstrap_assets.mjs
node tools/client_config.mjs
flutter pub get
flutter build web --wasm --release --dart-define-from-file=config/client.json
