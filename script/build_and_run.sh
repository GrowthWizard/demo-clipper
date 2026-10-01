#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CLIPPER_ROOT="$PWD"
CLIPPER_APP_NAME="Clipper Requesty"
CLIPPER_APP="$CLIPPER_ROOT/build/Build/Products/Release/$CLIPPER_APP_NAME.app"
CLIPPER_MODE="${1:-run}"
mkdir -p build

build_target() {
    xcodegen generate >build/generate.log 2>&1
    if ! xcodebuild -project Clipper.xcodeproj -scheme "$1" -configuration "$2" \
        -destination 'platform=macOS,arch=arm64' -derivedDataPath build ARCHS=arm64 CC="$CLIPPER_ROOT/script/clang-probe.sh" CXX="$CLIPPER_ROOT/script/clang-probe.sh" \
        -skipPackagePluginValidation -skipMacroValidation "$3" >"build/$1-$3.log" 2>&1; then
        tail -60 "build/$1-$3.log"
        return 1
    fi
    echo "$1: $3 succeeded"
}

launch_requesty() {
    # Optional process configuration goes to LaunchServices in memory.
    # The GUI launches as a native app bundle with normal Dock activation.
    [ -d "$CLIPPER_APP" ] || { echo 'Build the app first.'; return 1; }
    [ -n "${REQUESTY_API_KEY:-}" ] || { echo 'Set REQUESTY_API_KEY for this optional environment launch.'; return 1; }
    if [ -f build/app.pid ]; then
        CLIPPER_OLD_PID=$(cat build/app.pid)
        if [[ "$CLIPPER_OLD_PID" =~ ^[0-9]+$ ]] && \
           [ "$(ps -p "$CLIPPER_OLD_PID" -o comm= 2>/dev/null || true)" = "$CLIPPER_APP/Contents/MacOS/$CLIPPER_APP_NAME" ]; then
            kill "$CLIPPER_OLD_PID"
        fi
    fi
    if [ ! -x build/launch-with-environment ] || [ Tools/LaunchWithEnvironment.swift -nt build/launch-with-environment ]; then
        swiftc -parse-as-library Tools/LaunchWithEnvironment.swift -o build/launch-with-environment
    fi
    CLIPPER_PID=$(build/launch-with-environment "$CLIPPER_APP")
    echo "$CLIPPER_PID" >build/app.pid
    kill -0 "$CLIPPER_PID"
    echo "Clipper Requesty is running (PID $CLIPPER_PID)."
}

case "$CLIPPER_MODE" in
build) build_target Clipper Release build ;;
cli) build_target ClipperCLI Release build ;;
test) build_target ClipperTests Debug test ;;
run|run-local)
    build_target Clipper Release build
    /usr/bin/open -n "$CLIPPER_APP"
    ;;
launch-requesty) launch_requesty ;;
run-1password)
    build_target Clipper Release build
    CLIPPER_ENV_RUNNER="${CLIPPER_ENV_RUNNER:-$HOME/.agents/skills/1password-project-env/scripts/env.mjs}"
    [ -f "$CLIPPER_ENV_RUNNER" ] || { echo 'Install the 1password-project-env skill first.'; exit 1; }
    exec node "$CLIPPER_ENV_RUNNER" run --config "$CLIPPER_ROOT/.1password/project.json" \
        --project "$CLIPPER_ROOT" -- "$CLIPPER_ROOT/script/build_and_run.sh" launch-requesty
    ;;
*) echo 'Usage: script/build_and_run.sh build|cli|test|run|run-local|run-1password'; exit 2 ;;
esac
