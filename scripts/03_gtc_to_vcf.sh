#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <config.sh>"
    exit 1
}

[[ $# -eq 1 ]] || usage

CONFIG="$1"
[[ -f "$CONFIG" ]] || {
    echo "ERROR: config file not found: $CONFIG" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$CONFIG"

required_vars=(
    BCFTOOLS
    BCFTOOLS_PLUGINS
    BPM
    EGT
    CSV_MANIFEST
    REFERENCE_FASTA
    GENOME_BUILD
    OUTPUT_DIR
    VCF_TAGS
)

for var in "${required_vars[@]}"; do
    [[ -n "${!var:-}" ]] || {
        echo "ERROR: required config variable is unset: $var" >&2
        exit 1
    }
done

[[ -x "$BCFTOOLS" ]] || {
    echo "ERROR: bcftools is not executable: $BCFTOOLS" >&2
    exit 1
}

[[ -d "$BCFTOOLS_PLUGINS" ]] || {
    echo "ERROR: BCFTOOLS_PLUGINS directory not found: $BCFTOOLS_PLUGINS" >&2
    exit 1
}

for file in "$BPM" "$EGT" "$CSV_MANIFEST" "$REFERENCE_FASTA"; do
    [[ -f "$file" ]] || {
        echo "ERROR: required resource not found: $file" >&2
        exit 1
    }
done

[[ "$GENOME_BUILD" == "GRCh38" ]] || {
    echo "ERROR: this validated workflow currently requires GENOME_BUILD=GRCh38" >&2
    exit 1
}

GTC_DIR="$OUTPUT_DIR/gtc"
VCF_DIR="$OUTPUT_DIR/vcf"
LOG_DIR="$OUTPUT_DIR/logs"

[[ -d "$GTC_DIR" ]] || {
    echo "ERROR: GTC directory not found: $GTC_DIR" >&2
    exit 1
}

mkdir -p "$VCF_DIR" "$LOG_DIR"

export BCFTOOLS_PLUGINS

mapfile -t GTC_FILES < <(
    find "$GTC_DIR" -maxdepth 1 \
        \( -type f -o -type l \) \
        -iname '*.gtc' -print \
        | sort
)

for gtc in "${GTC_FILES[@]}"; do
    [[ -f "$gtc" ]] || {
        echo "ERROR: GTC path does not resolve to a regular file: $gtc" >&2
        exit 1
    }
done

[[ ${#GTC_FILES[@]} -gt 0 ]] || {
    echo "ERROR: no GTC files found in $GTC_DIR" >&2
    exit 1
}

GTC_LIST="$VCF_DIR/gtc.list"
printf '%s\n' "${GTC_FILES[@]}" > "$GTC_LIST"

UNSORTED="$VCF_DIR/genotypes.GRCh38.unsorted.vcf.gz"
FINAL="$VCF_DIR/genotypes.GRCh38.vcf.gz"

echo "=== SOFTWARE ==="
"$BCFTOOLS" --version | head -n 2

echo
echo "=== GTC INPUT ==="
echo "GTC files: ${#GTC_FILES[@]}"

echo
echo "=== GTC -> VCF ==="
echo "Genome build: $GENOME_BUILD"
echo "FORMAT tags: $VCF_TAGS"

"$BCFTOOLS" +gtc2vcf \
    --bpm "$BPM" \
    --csv "$CSV_MANIFEST" \
    --egt "$EGT" \
    --fasta-ref "$REFERENCE_FASTA" \
    --genome-build "$GENOME_BUILD" \
    --tags "$VCF_TAGS" \
    --gtcs "$GTC_LIST" \
    --output "$UNSORTED" \
    --output-type z \
    2>&1 | tee "$LOG_DIR/gtc2vcf.log"

echo
echo "=== SORT AND INDEX ==="

"$BCFTOOLS" sort \
    --output-type z \
    --output "$FINAL" \
    "$UNSORTED"

"$BCFTOOLS" index --force "$FINAL"

echo
echo "=== OUTPUT CHECK ==="

sample_count="$("$BCFTOOLS" query -l "$FINAL" | wc -l)"
record_count="$("$BCFTOOLS" view -H "$FINAL" | wc -l)"

echo "Input GTCs: $(( ${#GTC_FILES[@]} ))"
echo "VCF samples: $sample_count"
echo "VCF records: $record_count"

[[ "$sample_count" -eq "${#GTC_FILES[@]}" ]] || {
    echo "ERROR: GTC and VCF sample counts differ." >&2
    exit 1
}

echo "Status: PASS"
