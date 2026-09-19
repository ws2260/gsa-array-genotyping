#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <config.sh> <output_dir>"
    exit 1
}

[[ $# -eq 2 ]] || usage

CONFIG="$1"
PROV_DIR="$2"

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

mkdir -p "$PROV_DIR"

export BCFTOOLS_PLUGINS

VERSIONS="$PROV_DIR/software_versions.txt"
SETTINGS="$PROV_DIR/settings.txt"
CHECKSUMS="$PROV_DIR/resource_checksums.sha256"

{
    echo "bcftools:"
    "$BCFTOOLS" --version | head -n 2

    idat2gtc_help="$(
        "$BCFTOOLS" +idat2gtc -h 2>&1 || true
    )"

    idat2gtc_version="$(
        printf '%s\n' "$idat2gtc_help" \
            | sed -nE 's/.*\(version ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p' \
            | head -n 1
    )"

    [[ -n "$idat2gtc_version" ]] || {
        echo "ERROR: unable to determine idat2gtc version" >&2
        exit 1
    }

    gtc2vcf_help="$(
        "$BCFTOOLS" +gtc2vcf -h 2>&1 || true
    )"

    gtc2vcf_version="$(
        printf '%s\n' "$gtc2vcf_help" \
            | sed -nE 's/.*\(version ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p' \
            | head -n 1
    )"

    [[ -n "$gtc2vcf_version" ]] || {
        echo "ERROR: unable to determine gtc2vcf version" >&2
        exit 1
    }

    echo
    echo "idat2gtc:"
    echo "idat2gtc $idat2gtc_version"

    echo
    echo "gtc2vcf:"
    echo "gtc2vcf $gtc2vcf_version"
} > "$VERSIONS"

{
    printf 'genome_build\t%s\n' "$GENOME_BUILD"
    printf 'idat2gtc_preset\t%s\n' "$IDAT2GTC_PRESET"
    printf 'vcf_tags\t%s\n' "$VCF_TAGS"

    printf 'bpm_filename\t%s\n' "$(basename "$BPM")"
    printf 'egt_filename\t%s\n' "$(basename "$EGT")"
    printf 'csv_manifest_filename\t%s\n' "$(basename "$CSV_MANIFEST")"
    printf 'reference_filename\t%s\n' "$(basename "$REFERENCE_FASTA")"

    printf 'allow_missing_clusters\tfalse\n'
    printf 'adjust_clusters\tfalse\n'
} > "$SETTINGS"

{
    printf '%s  %s\n' \
        "$(sha256sum "$BPM" | cut -d' ' -f1)" \
        "$(basename "$BPM")"

    printf '%s  %s\n' \
        "$(sha256sum "$EGT" | cut -d' ' -f1)" \
        "$(basename "$EGT")"

    printf '%s  %s\n' \
        "$(sha256sum "$CSV_MANIFEST" | cut -d' ' -f1)" \
        "$(basename "$CSV_MANIFEST")"

    printf '%s  %s\n' \
        "$(sha256sum "$REFERENCE_FASTA" | cut -d' ' -f1)" \
        "$(basename "$REFERENCE_FASTA")"
} > "$CHECKSUMS"

echo "=== PROVENANCE CAPTURE ==="
echo "Software versions: PASS"
echo "Pipeline settings: PASS"
echo "Resource checksums: PASS"
echo "Status: PASS"
