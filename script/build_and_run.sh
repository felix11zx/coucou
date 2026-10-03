#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
case "$MODE" in
    run|--build-only|--verify|--debug|--logs|--telemetry) ;;
    *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/NotchBuddy/build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/Coucou.app"
if [[ "$MODE" != "--build-only" ]]; then
    pkill -x Coucou >/dev/null 2>&1 || true
fi
cd "$ROOT_DIR/NotchBuddy"
xcodegen
xcodebuild -project NotchBuddy.xcodeproj -scheme NotchBuddy \
    -configuration Debug -derivedDataPath "$BUILD_DIR" build \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
if [[ "$MODE" == "--build-only" ]]; then exit 0; fi
# Locally built apps need an ad-hoc signature for a reliable launch.
codesign --force --deep --sign - "$APP_BUNDLE"
case "$MODE" in
    --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/Coucou" ;;
    --logs|--telemetry)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate 'process == "Coucou"'
        ;;
    --verify)
        /usr/bin/open -n "$APP_BUNDLE"
        sleep 2
        pgrep -x Coucou >/dev/null
        ;;
    run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
