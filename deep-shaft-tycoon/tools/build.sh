#!/usr/bin/env bash
#
# Build Deep Shaft Tycoon for the Venu 2 family.
#
#   tools/build.sh                    # build every device, strict type checking
#   tools/build.sh venu2              # just one
#   tools/build.sh --fetch-sdk        # download the SDK first, then build
#   CIQ_SDK=~/my-sdk tools/build.sh   # point at an existing SDK
#
# Needs java and python3. If you already use the graphical SDK Manager, set
# CIQ_SDK to your SDK folder; otherwise --fetch-sdk pulls the current Linux SDK
# into build/sdk. Device configurations are generated from the SDK's own device
# table (see tools/make_device_json.py), so the SDK Manager is not required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
SDK="${CIQ_SDK:-$BUILD/sdk}"
KEY="${CIQ_KEY:-$BUILD/developer_key.der}"
DEVICES_DIR="$BUILD/devices"
TYPECHECK="${CIQ_TYPECHECK:-3}"
SDK_INDEX="https://developer.garmin.com/downloads/connect-iq/sdks"

fetch_sdk=0
targets=()
for arg in "$@"; do
    case "$arg" in
        --fetch-sdk) fetch_sdk=1 ;;
        -*) echo "unknown option: $arg" >&2; exit 2 ;;
        *) targets+=("$arg") ;;
    esac
done
if [ ${#targets[@]} -eq 0 ]; then
    targets=(venu2 venu2s venu2plus)
fi

mkdir -p "$BUILD"

if [ "$fetch_sdk" = 1 ] && [ ! -d "$SDK/bin" ]; then
    echo "==> fetching the Connect IQ SDK"
    curl -fsSL "$SDK_INDEX/sdks.json" -o "$BUILD/sdks.json"
    name="$(python3 -c "
import json
entries = json.load(open('$BUILD/sdks.json'))
print(sorted(entries, key=lambda e: [int(p) for p in e['version'].split('.')])[-1]['linux'])
")"
    echo "    $name"
    curl -fsSL "$SDK_INDEX/$name" -o "$BUILD/sdk.zip"
    mkdir -p "$SDK"
    unzip -q -o "$BUILD/sdk.zip" -d "$SDK"
    chmod +x "$SDK"/bin/* 2>/dev/null || true
fi

if [ ! -f "$SDK/bin/monkeybrains.jar" ]; then
    echo "no Connect IQ SDK at $SDK" >&2
    echo "run 'tools/build.sh --fetch-sdk', or set CIQ_SDK to your SDK folder" >&2
    exit 1
fi

# A developer key signs the build. It is personal and never committed; any RSA
# key works for sideloading, and the store wants the one you registered with.
if [ ! -f "$KEY" ]; then
    echo "==> generating a developer key at $KEY"
    openssl genrsa -out "$BUILD/developer_key.pem" 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER \
        -in "$BUILD/developer_key.pem" -out "$KEY" -nocrypt
fi

echo "==> generating device configurations"
python3 "$ROOT/tools/make_device_json.py" --sdk "$SDK" --out "$DEVICES_DIR" \
    "${targets[@]}" >/dev/null

echo "==> checking the round-screen layout"
python3 "$ROOT/tools/check_layout.py"

status=0
for device in "${targets[@]}"; do
    echo "==> building $device"
    if java -jar "$SDK/bin/monkeybrains.jar" \
        --jungles "$ROOT/monkey.jungle" \
        --output "$BUILD/$device.prg" \
        --apidb "$SDK/bin/api.db" \
        --apimir "$SDK/bin/api.mir" \
        --override-devices-json "$DEVICES_DIR" \
        --device "$device" \
        --private-key "$KEY" \
        --typecheck "$TYPECHECK" \
        --warn; then
        echo "    $BUILD/$device.prg ($(wc -c <"$BUILD/$device.prg") bytes)"
    else
        status=1
    fi
done

exit $status
