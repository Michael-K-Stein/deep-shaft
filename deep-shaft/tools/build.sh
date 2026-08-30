#!/usr/bin/env bash
#
# Build Deep Shaft for every supported product.
#
# Output goes to deep-shaft/bin/ regardless of where this is invoked from, so a
# build never drops artifacts in the repository root.
#
# Usage:
#   tools/build.sh                 # build every product
#   tools/build.sh venu2           # build one product
#
# Environment:
#   CIQ_HOME        Connect IQ SDK root (else monkeyc must be on PATH)
#   DEVELOPER_KEY   path to the signing key (default ~/.Garmin/developer_key.der)
#   TYPECHECK       monkeyc -l level (default 3, the strict checker)

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${project_dir}/bin"

if [[ -n "${CIQ_HOME:-}" ]]; then
    monkeyc="${CIQ_HOME}/bin/monkeyc"
else
    monkeyc="$(command -v monkeyc || true)"
fi

if [[ ! -x "${monkeyc}" ]]; then
    echo "error: monkeyc not found. Set CIQ_HOME to the Connect IQ SDK root," >&2
    echo "       or put the SDK's bin directory on PATH." >&2
    exit 1
fi

key="${DEVELOPER_KEY:-${HOME}/.Garmin/developer_key.der}"
if [[ ! -f "${key}" ]]; then
    echo "error: signing key not found at ${key}." >&2
    echo "       Generate one with:" >&2
    echo "         openssl genrsa -out key.pem 4096" >&2
    echo "         openssl pkcs8 -topk8 -inform PEM -outform DER \\" >&2
    echo "           -in key.pem -out developer_key.der -nocrypt" >&2
    echo "       then point DEVELOPER_KEY at the .der file." >&2
    exit 1
fi

if [[ $# -gt 0 ]]; then
    products=("$@")
else
    products=(venu2 venu2s venu2plus)
fi

mkdir -p "${out_dir}"

for product in "${products[@]}"; do
    echo "==> ${product}"
    "${monkeyc}" \
        -f "${project_dir}/monkey.jungle" \
        -o "${out_dir}/DeepShaft-${product}.prg" \
        -d "${product}" \
        -y "${key}" \
        -l "${TYPECHECK:-3}" \
        -w
done

echo
echo "Wrote to ${out_dir}:"
ls -1 "${out_dir}"/*.prg
