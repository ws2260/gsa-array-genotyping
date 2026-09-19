#!/usr/bin/env bash

# Example configuration for gsa-array-genotyping.
# Copy this file outside the repository or rename it for local use.
# Do not commit sample-specific paths or genomic data.

# ---- Software ---------------------------------------------------------------

# bcftools executable built with access to the idat2gtc/gtc2vcf plugins.
BCFTOOLS="/path/to/bcftools"

# Directory containing the bcftools plugins.
BCFTOOLS_PLUGINS="/path/to/bcftools/plugins"


# ---- Input data -------------------------------------------------------------

# Illumina array resources compatible with the IDAT data.
BPM="/path/to/manifest.bpm"
EGT="/path/to/cluster_file.egt"
CSV_MANIFEST="/path/to/manifest.csv"

# Reference FASTA used for VCF construction.
REFERENCE_FASTA="/path/to/GRCh38_reference.fasta"

# Genome-build label passed explicitly to gtc2vcf.
GENOME_BUILD="GRCh38"


# ---- Output -----------------------------------------------------------------

# Root directory for generated files.
OUTPUT_DIR="/path/to/run_output"


# ---- Calling / VCF settings -------------------------------------------------

# Explicitly emulate Illumina Array Analysis CLI behavior.
IDAT2GTC_PRESET="4"

# FORMAT fields retained in the cohort VCF.
VCF_TAGS="GT,GQ,IGC,BAF,LRR,R,THETA"

