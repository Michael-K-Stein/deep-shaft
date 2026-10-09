#!/usr/bin/env bash
#
# Every check that does not need the Connect IQ SDK. This is the fast gate:
# run it before compiling, and after any change to the balance constants.
#
#   tools/verify.sh
#
# tools/build.sh runs the layout check on its own, so a plain build is still
# safe; this adds the constant-drift check and an economy smoke run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The Windows Store ships a `python3` stub that only prints an advert, so the
# interpreter is probed rather than just located.
if [ -z "${PYTHON:-}" ]; then
    for candidate in python3 python py; do
        if command -v "$candidate" >/dev/null 2>&1 &&
           "$candidate" -c "import sys" >/dev/null 2>&1; then
            PYTHON="$candidate"
            break
        fi
    done
fi
if [ -z "${PYTHON:-}" ]; then
    echo "no working python interpreter found; set PYTHON to one" >&2
    exit 1
fi

echo "==> constants agree between Balance.mc and the tools"
"$PYTHON" "$ROOT/tools/check_constants.py"

echo
echo "==> the round-screen layout"
"$PYTHON" "$ROOT/tools/check_layout.py"

echo "==> the difficulty curve still resolves"
"$PYTHON" "$ROOT/tools/simulate_economy.py" --hours 2 --taps 1 | tail -n 9

echo
echo "==> no delegate re-fires a tap as a select"
"$PYTHON" "$ROOT/tools/check_input.py"
