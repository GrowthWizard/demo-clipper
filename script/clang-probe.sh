#!/bin/bash
set -euo pipefail
# Xcode 26.6's CLI probe can block while capturing clang's verbose stderr.
# -v changes diagnostics only; keep macro output and all compilation flags.
CLIPPER_ARGS=()
CLIPPER_PROBE=0
for arg in "$@"; do [ "$arg" != '-dM' ] || CLIPPER_PROBE=1; done
for arg in "$@"; do
    if [ "$CLIPPER_PROBE" = 1 ] && [ "$arg" = '-v' ]; then continue; fi
    CLIPPER_ARGS+=("$arg")
done
exec "$(xcrun --find clang)" "${CLIPPER_ARGS[@]}"
