#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <cohort_output_dir> <batch_output_dir> [<batch_output_dir> ...]"
    exit 1
}

[[ $# -ge 2 ]] || usage

COHORT_OUTPUT_DIR="$1"
shift

COHORT_GTC_DIR="$COHORT_OUTPUT_DIR/gtc"
PROVENANCE_DIR="$COHORT_OUTPUT_DIR/provenance"
PROVENANCE_FILE="$PROVENANCE_DIR/gtc_sources.tsv"

mkdir -p "$COHORT_GTC_DIR" "$PROVENANCE_DIR"

# Refuse to assemble into a non-empty cohort GTC directory.
if find "$COHORT_GTC_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "ERROR: cohort GTC directory is not empty:" >&2
    echo "$COHORT_GTC_DIR" >&2
    exit 1
fi

declare -A seen
total=0

# Validate all inputs and detect basename collisions before creating links.
for batch_output in "$@"; do
    batch_gtc_dir="$batch_output/gtc"

    [[ -d "$batch_gtc_dir" ]] || {
        echo "ERROR: batch GTC directory not found: $batch_gtc_dir" >&2
        exit 1
    }

    found=0

    while IFS= read -r -d '' gtc; do
        found=1
        base="$(basename "$gtc")"

        if [[ -n "${seen[$base]:-}" ]]; then
            echo "ERROR: duplicate GTC basename across batches: $base" >&2
            exit 1
        fi

        seen["$base"]="$gtc"
        ((total+=1))
    done < <(
        find "$batch_gtc_dir" -maxdepth 1 -type f -iname '*.gtc' -print0
    )

    [[ "$found" -eq 1 ]] || {
        echo "ERROR: no GTC files found in: $batch_gtc_dir" >&2
        exit 1
    }
done

# Write provenance and create links only after validation succeeds.
printf 'gtc_basename\tbatch_output_dir\tsource_gtc\n' > "$PROVENANCE_FILE"

for batch_output in "$@"; do
    batch_gtc_dir="$batch_output/gtc"

    while IFS= read -r -d '' gtc; do
        base="$(basename "$gtc")"

        # Resolve the source to an absolute path before linking.
        source_abs="$(realpath "$gtc")"

        ln -s "$source_abs" "$COHORT_GTC_DIR/$base"

        printf '%s\t%s\t%s\n' \
            "$base" \
            "$(realpath "$batch_output")" \
            "$source_abs" \
            >> "$PROVENANCE_FILE"

    done < <(
        find "$batch_gtc_dir" -maxdepth 1 -type f -iname '*.gtc' -print0 \
        | sort -z
    )
done

observed="$(
    find "$COHORT_GTC_DIR" -maxdepth 1 -type l -iname '*.gtc' | wc -l
)"

echo "=== COHORT ASSEMBLY ==="
echo "Input batch directories: $#"
echo "Source GTCs: $total"
echo "Linked cohort GTCs: $observed"

if [[ "$observed" -ne "$total" ]]; then
    echo "ERROR: assembled GTC count does not match source count." >&2
    exit 1
fi

echo "Status: PASS"
echo
echo "Detailed provenance written locally:"
echo "$PROVENANCE_FILE"
