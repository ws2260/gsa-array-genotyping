#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <config.sh> <batches.tsv>"
    exit 1
}

[[ $# -eq 2 ]] || usage

CONFIG="$1"
BATCH_MANIFEST="$2"

[[ -f "$CONFIG" ]] || {
    echo "ERROR: config file not found: $CONFIG" >&2
    exit 1
}

[[ -f "$BATCH_MANIFEST" ]] || {
    echo "ERROR: batch manifest not found: $BATCH_MANIFEST" >&2
    exit 1
}

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

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
    IDAT2GTC_PRESET
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
    echo "ERROR: plugin directory not found: $BCFTOOLS_PLUGINS" >&2
    exit 1
}

for resource in "$BPM" "$EGT" "$CSV_MANIFEST" "$REFERENCE_FASTA"; do
    [[ -f "$resource" ]] || {
        echo "ERROR: required resource not found: $resource" >&2
        exit 1
    }
done

[[ "$GENOME_BUILD" == "GRCh38" ]] || {
    echo "ERROR: current validated workflow requires GENOME_BUILD=GRCh38" >&2
    exit 1
}

[[ "$IDAT2GTC_PRESET" =~ ^[1-4]$ ]] || {
    echo "ERROR: IDAT2GTC_PRESET must be 1, 2, 3, or 4." >&2
    exit 1
}

echo "=== PIPELINE PREFLIGHT ==="

header="$(
    head -n 1 "$BATCH_MANIFEST" |
    tr -d '\r'
)"

expected_header=$'batch_id\tidat_dir'

[[ "$header" == "$expected_header" ]] || {
    echo "ERROR: batch manifest header must be exactly:" >&2
    printf '%s\n' "$expected_header" >&2
    exit 1
}

declare -a BATCH_IDS=()
declare -a IDAT_DIRS=()
declare -A SEEN_BATCH_IDS=()
declare -A SEEN_IDAT_DIRS=()

line_no=1

while IFS=$'\t' read -r batch_id idat_dir extra; do
    ((line_no+=1))

    batch_id="${batch_id%$'\r'}"
    idat_dir="${idat_dir%$'\r'}"

    [[ -n "$batch_id" || -n "$idat_dir" || -n "${extra:-}" ]] || continue

    [[ -z "${extra:-}" ]] || {
        echo "ERROR: line $line_no has more than two columns." >&2
        exit 1
    }

    [[ -n "$batch_id" && -n "$idat_dir" ]] || {
        echo "ERROR: line $line_no has an empty batch_id or idat_dir." >&2
        exit 1
    }

    [[ "$batch_id" =~ ^[A-Za-z0-9_-]+$ ]] || {
        echo "ERROR: invalid batch_id on line $line_no: $batch_id" >&2
        echo "Allowed characters: A-Z a-z 0-9 _ -" >&2
        exit 1
    }

    [[ -z "${SEEN_BATCH_IDS[$batch_id]:-}" ]] || {
        echo "ERROR: duplicate batch_id: $batch_id" >&2
        exit 1
    }

    [[ -d "$idat_dir" ]] || {
        echo "ERROR: IDAT directory not found for batch $batch_id" >&2
        exit 1
    }

    idat_abs="$(realpath "$idat_dir")"

    [[ -z "${SEEN_IDAT_DIRS[$idat_abs]:-}" ]] || {
        echo "ERROR: duplicate IDAT directory in manifest." >&2
        exit 1
    }

    SEEN_BATCH_IDS["$batch_id"]=1
    SEEN_IDAT_DIRS["$idat_abs"]=1

    BATCH_IDS+=("$batch_id")
    IDAT_DIRS+=("$idat_abs")

done < <(tail -n +2 "$BATCH_MANIFEST")

[[ ${#BATCH_IDS[@]} -gt 0 ]] || {
    echo "ERROR: batch manifest contains no batches." >&2
    exit 1
}

echo "Batches: ${#BATCH_IDS[@]}"

echo
echo "=== IDAT PREFLIGHT FOR ALL BATCHES ==="

for i in "${!BATCH_IDS[@]}"; do
    echo
    echo "Batch: ${BATCH_IDS[$i]}"
    "$SCRIPT_DIR/scripts/01_check_idats.sh" "${IDAT_DIRS[$i]}"
done

# Refuse to mix a new run with pre-existing output.
if [[ -e "$OUTPUT_DIR" ]]; then
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        echo "ERROR: OUTPUT_DIR exists and is not a directory." >&2
        exit 1
    fi

    if find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
        echo "ERROR: OUTPUT_DIR already exists and is not empty:" >&2
        echo "$OUTPUT_DIR" >&2
        exit 1
    fi
fi

mkdir -p \
    "$OUTPUT_DIR/batches" \
    "$OUTPUT_DIR/cohort" \
    "$OUTPUT_DIR/run_configs" \
    "$OUTPUT_DIR/provenance"

echo
echo "=== CAPTURE PROVENANCE ==="

"$SCRIPT_DIR/scripts/00_capture_provenance.sh" \
    "$CONFIG" \
    "$OUTPUT_DIR/provenance"

declare -a BATCH_OUTPUTS=()

echo
echo "=== IDAT -> GTC BY BATCH ==="

for i in "${!BATCH_IDS[@]}"; do
    batch_id="${BATCH_IDS[$i]}"
    idat_dir="${IDAT_DIRS[$i]}"
    batch_output="$OUTPUT_DIR/batches/$batch_id"
    batch_config="$OUTPUT_DIR/run_configs/${batch_id}.config.sh"

    BATCH_OUTPUTS+=("$batch_output")

    {
        printf '#!/usr/bin/env bash\n'
        printf 'BCFTOOLS=%q\n' "$BCFTOOLS"
        printf 'BCFTOOLS_PLUGINS=%q\n' "$BCFTOOLS_PLUGINS"
        printf 'IDAT_DIR=%q\n' "$idat_dir"
        printf 'BPM=%q\n' "$BPM"
        printf 'EGT=%q\n' "$EGT"
        printf 'CSV_MANIFEST=%q\n' "$CSV_MANIFEST"
        printf 'REFERENCE_FASTA=%q\n' "$REFERENCE_FASTA"
        printf 'GENOME_BUILD=%q\n' "$GENOME_BUILD"
        printf 'OUTPUT_DIR=%q\n' "$batch_output"
        printf 'IDAT2GTC_PRESET=%q\n' "$IDAT2GTC_PRESET"
        printf 'VCF_TAGS=%q\n' "$VCF_TAGS"
    } > "$batch_config"

    echo
    echo "Batch: $batch_id"

    "$SCRIPT_DIR/scripts/02_idat_to_gtc.sh" "$batch_config"
done

echo
echo "=== ASSEMBLE COHORT ==="

"$SCRIPT_DIR/scripts/05_assemble_cohort.sh" \
    "$OUTPUT_DIR/cohort" \
    "${BATCH_OUTPUTS[@]}"

COHORT_CONFIG="$OUTPUT_DIR/run_configs/cohort.config.sh"

{
    printf '#!/usr/bin/env bash\n'
    printf 'BCFTOOLS=%q\n' "$BCFTOOLS"
    printf 'BCFTOOLS_PLUGINS=%q\n' "$BCFTOOLS_PLUGINS"
    printf 'BPM=%q\n' "$BPM"
    printf 'EGT=%q\n' "$EGT"
    printf 'CSV_MANIFEST=%q\n' "$CSV_MANIFEST"
    printf 'REFERENCE_FASTA=%q\n' "$REFERENCE_FASTA"
    printf 'GENOME_BUILD=%q\n' "$GENOME_BUILD"
    printf 'OUTPUT_DIR=%q\n' "$OUTPUT_DIR/cohort"
    printf 'IDAT2GTC_PRESET=%q\n' "$IDAT2GTC_PRESET"
    printf 'VCF_TAGS=%q\n' "$VCF_TAGS"
} > "$COHORT_CONFIG"

echo
echo "=== COHORT GTC -> VCF ==="

"$SCRIPT_DIR/scripts/03_gtc_to_vcf.sh" \
    "$COHORT_CONFIG"

echo
echo "=== COHORT VCF QC ==="

"$SCRIPT_DIR/scripts/04_vcf_qc.sh" \
    "$COHORT_CONFIG"

echo
echo "=== FINAL OUTPUT CHECKSUMS ==="

FINAL_VCF="$OUTPUT_DIR/cohort/vcf/genotypes.GRCh38.vcf.gz"
FINAL_INDEX="${FINAL_VCF}.csi"
OUTPUT_CHECKSUMS="$OUTPUT_DIR/provenance/output_checksums.sha256"

if [[ ! -f "$FINAL_VCF" ]]; then
    echo "ERROR: final VCF not found: $FINAL_VCF" >&2
    exit 1
fi

if [[ ! -f "$FINAL_INDEX" ]]; then
    echo "ERROR: final VCF index not found: $FINAL_INDEX" >&2
    exit 1
fi

{
    printf '%s  %s\n' "$(sha256sum "$FINAL_VCF" | cut -d' ' -f1)" "cohort/vcf/$(basename "$FINAL_VCF")"
    printf '%s  %s\n' "$(sha256sum "$FINAL_INDEX" | cut -d' ' -f1)" "cohort/vcf/$(basename "$FINAL_INDEX")"
} > "$OUTPUT_CHECKSUMS"

echo "Final VCF checksum: PASS"
echo "Final index checksum: PASS"

echo
echo "=== PIPELINE COMPLETE ==="
echo "Batches processed: ${#BATCH_IDS[@]}"
echo "Run output: $OUTPUT_DIR"
echo "Status: PASS"
