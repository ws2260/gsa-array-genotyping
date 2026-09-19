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

VCF="$OUTPUT_DIR/vcf/genotypes.GRCh38.vcf.gz"
QC_DIR="$OUTPUT_DIR/qc"

[[ -f "$VCF" ]] || {
    echo "ERROR: VCF not found: $VCF" >&2
    exit 1
}

[[ -f "${VCF}.csi" || -f "${VCF}.tbi" ]] || {
    echo "ERROR: VCF index not found." >&2
    exit 1
}

mkdir -p "$QC_DIR"

SAMPLE_QC="$QC_DIR/sample_qc.tsv"
VCFSTATS="$QC_DIR/bcftools.stats.txt"

echo "=== VCF QC ==="

sample_count="$("$BCFTOOLS" query -l "$VCF" | wc -l)"
record_count="$("$BCFTOOLS" view -H "$VCF" | wc -l)"

echo "Samples: $sample_count"
echo "Records: $record_count"

echo
echo "=== FORMAT CHECK ==="

header="$("$BCFTOOLS" view -h "$VCF")"

IFS=',' read -r -a expected_tags <<< "$VCF_TAGS"

for tag in "${expected_tags[@]}"; do
    if grep -q "^##FORMAT=<ID=${tag}," <<< "$header"; then
        echo "$tag: present"
    else
        echo "ERROR: expected FORMAT field missing: $tag" >&2
        exit 1
    fi
done

echo
echo "=== STANDARD VCF STATS ==="

"$BCFTOOLS" stats -s - "$VCF" > "$VCFSTATS"

grep '^SN' "$VCFSTATS" \
    | grep -E 'number of samples:|number of records:|number of SNPs:|number of indels:|number of multiallelic sites:'

echo
echo "=== PER-SAMPLE GT CALL RATE ==="

{
    printf 'sample\ttotal_records\tcalled_gt\tmissing_gt\tcall_rate\n'

    "$BCFTOOLS" query -l "$VCF" | while IFS= read -r sample; do
        counts="$(
            "$BCFTOOLS" query \
                -s "$sample" \
                -f '[%GT\n]' \
                "$VCF" \
            | awk '
                BEGIN {
                    total=0
                    called=0
                    missing=0
                }
                {
                    total++
                    if ($0=="." || $0=="./." || $0==".|." ||
                        $0 ~ /^\.\// || $0 ~ /\/\.$/ ||
                        $0 ~ /^\.\|/ || $0 ~ /\|\.$/) {
                        missing++
                    } else {
                        called++
                    }
                }
                END {
                    printf "%d\t%d\t%d\t%.8f",
                           total, called, missing,
                           (total > 0 ? called/total : 0)
                }
            '
        )"

        printf '%s\t%s\n' "$sample" "$counts"
    done
} > "$SAMPLE_QC"

awk -F'\t' '
NR==1 { next }
{
    n++
    sum += $5

    if (n==1 || $5 < min)
        min=$5

    if (n==1 || $5 > max)
        max=$5
}
END {
    printf "Samples summarized: %d\n", n
    if (n > 0) {
        printf "Mean VCF call rate: %.8f\n", sum/n
        printf "Min VCF call rate:  %.8f\n", min
        printf "Max VCF call rate:  %.8f\n", max
    }
}
' "$SAMPLE_QC"

echo
echo "Per-sample QC written locally:"
echo "$SAMPLE_QC"

echo
echo "=== LOCUS GT MISSINGNESS ==="

LOCUS_QC="$QC_DIR/locus_qc.tsv"
LOCUS_SUMMARY="$QC_DIR/locus_qc.summary.txt"

"$BCFTOOLS" query -f '%CHROM\t%POS\t%ID[\t%GT]\n' "$VCF" \
| awk -F'\t' -v OFS='\t' \
    -v locus_qc="$LOCUS_QC" \
    -v locus_summary="$LOCUS_SUMMARY" '
BEGIN {
    print "chrom", "pos", "id", "n_samples", "n_called",           "n_missing", "missing_rate" > locus_qc

    total_loci=0
    complete=0
    any_missing=0
    missing_5=0
    missing_10=0
    missing_20=0
    total_missing_calls=0
}
{
    total_loci++
    n_samples=NF-3
    missing=0

    for (i=4; i<=NF; i++) {
        gt=$i

        if (gt=="." || gt=="./." || gt==".|." ||
            gt ~ /^\.\// || gt ~ /\/\.$/ ||
            gt ~ /^\.\|/ || gt ~ /\|\.$/) {
            missing++
        }
    }

    called=n_samples-missing
    rate=(n_samples > 0 ? missing/n_samples : 0)

    print $1, $2, $3, n_samples, called, missing,           sprintf("%.8f", rate) > locus_qc

    total_missing_calls += missing

    if (missing==0)
        complete++
    else
        any_missing++

    if (rate >= 0.05)
        missing_5++

    if (rate >= 0.10)
        missing_10++

    if (rate >= 0.20)
        missing_20++
}
END {
    print "Total loci: " total_loci > locus_summary
    print "Complete loci: " complete >> locus_summary
    print "Loci with any missing GT: " any_missing >> locus_summary
    print "Loci with >=5% missing GT: " missing_5 >> locus_summary
    print "Loci with >=10% missing GT: " missing_10 >> locus_summary
    print "Loci with >=20% missing GT: " missing_20 >> locus_summary
    print "Total missing GT calls: " total_missing_calls >> locus_summary
}
'

cat "$LOCUS_SUMMARY"

echo
echo "Locus-level QC written locally:"
echo "$LOCUS_QC"

echo
echo "Status: PASS"
