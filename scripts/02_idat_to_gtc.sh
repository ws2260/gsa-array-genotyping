#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<USAGE
Usage:
  $0 <config.sh>

Required config variables:
  BCFTOOLS
  BCFTOOLS_PLUGINS
  IDAT_DIR
  BPM
  EGT
  OUTPUT_DIR
  IDAT2GTC_PRESET
USAGE
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

CONFIG="$1"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: config file not found: $CONFIG" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG"

required_vars=(
    BCFTOOLS
    BCFTOOLS_PLUGINS
    IDAT_DIR
    BPM
    EGT
    OUTPUT_DIR
    IDAT2GTC_PRESET
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: required config variable is unset: $var" >&2
        exit 1
    fi
done

if [[ ! -x "$BCFTOOLS" ]]; then
    echo "ERROR: bcftools executable not found or not executable." >&2
    exit 1
fi

if [[ ! -d "$BCFTOOLS_PLUGINS" ]]; then
    echo "ERROR: bcftools plugin directory not found." >&2
    exit 1
fi

if [[ ! -d "$IDAT_DIR" ]]; then
    echo "ERROR: IDAT directory not found." >&2
    exit 1
fi

if [[ ! -f "$BPM" ]]; then
    echo "ERROR: BPM file not found." >&2
    exit 1
fi

if [[ ! -f "$EGT" ]]; then
    echo "ERROR: EGT file not found." >&2
    exit 1
fi

if [[ ! "$IDAT2GTC_PRESET" =~ ^[1-4]$ ]]; then
    echo "ERROR: IDAT2GTC_PRESET must be 1, 2, 3, or 4." >&2
    exit 1
fi

export BCFTOOLS_PLUGINS

GTC_DIR="$OUTPUT_DIR/gtc"
LOG_DIR="$OUTPUT_DIR/logs"

mkdir -p "$GTC_DIR" "$LOG_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/01_check_idats.sh" "$IDAT_DIR"

echo
echo "=== SOFTWARE ==="
"$BCFTOOLS" --version | head -n 2

echo
echo "=== IDAT -> GTC ==="
echo "Preset: $IDAT2GTC_PRESET"
echo "Output directory: $GTC_DIR"

"$BCFTOOLS" +idat2gtc \
    --bpm "$BPM" \
    --egt "$EGT" \
    --idats "$IDAT_DIR" \
    --output "$GTC_DIR" \
    --preset "$IDAT2GTC_PRESET" \
    2>&1 | tee "$LOG_DIR/idat2gtc.log"

echo
echo "=== OUTPUT CHECK ==="

expected_pairs="$(
    find "$IDAT_DIR" -maxdepth 1 \
        \( -type f -o -type l \) \
        \( -iname '*_Grn.idat' -o -iname '*_Red.idat' \) \
        -printf '%f\n' \
        | sed -E 's/_(Grn|Red)\.idat$//' \
        | sort -u \
        | wc -l
)"

observed_gtcs="$(
    find "$GTC_DIR" -maxdepth 1 -type f -iname '*.gtc' | wc -l
)"

echo "Expected GTCs: $expected_pairs"
echo "Observed GTCs: $observed_gtcs"

if [[ "$observed_gtcs" -ne "$expected_pairs" ]]; then
    echo "ERROR: GTC count does not match the number of IDAT pairs." >&2
    exit 1
fi

echo "Status: PASS"
