#!/usr/bin/env bash
set -euo pipefail

# Safety check for a repository intended to be public.
# Examines files known to Git (tracked or staged), not ignored runtime data.

forbidden_regex='(\.idat|\.gtc|\.vcf|\.vcf\.gz|\.bcf|\.bcf\.gz|\.bpm|\.egt|\.fasta|\.fasta\.gz|\.fna|\.fna\.gz|\.fa|\.fa\.gz|\.fai|\.dict|\.tbi|\.csi)$'

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    files="$(
        {
            git ls-files
            git diff --cached --name-only --diff-filter=ACMR
        } | sort -u
    )"

    bad="$(
        printf '%s\n' "$files" |
        grep -Ei "$forbidden_regex" || true
    )"

    if [[ -n "$bad" ]]; then
        echo "ERROR: genomic data or local resource files are known to Git:" >&2
        printf '%s\n' "$bad" >&2
        exit 1
    fi
else
    echo "Not yet a Git repository; checking non-ignored filenames is deferred."
fi

echo "Public-repository file check: PASS"
