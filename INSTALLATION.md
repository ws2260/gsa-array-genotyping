# Installation

## Overview

gsa-array-genotyping is a shell-based workflow built around bcftools and the idat2gtc and gtc2vcf plugins.

The workflow has been tested with:

- Linux under WSL2
- bcftools 1.24
- htslib 1.24
- idat2gtc 2026-01-26
- gtc2vcf 2026-01-26

Other versions may work but have not been validated with this workflow.

## 1. Install bcftools and the array plugins

Build or install bcftools together with the idat2gtc and gtc2vcf plugins following the instructions provided by the upstream projects.

After installation, confirm that bcftools is available:

    /path/to/bcftools --version

Then configure the plugin directory:

    export BCFTOOLS_PLUGINS=/path/to/bcftools/plugins

Confirm that both plugins can be loaded:

    /path/to/bcftools +idat2gtc -h
    /path/to/bcftools +gtc2vcf -h

Note that the tested plugin versions return a non-zero status after displaying help. The workflow therefore determines plugin versions from the emitted help text rather than using the help-command exit status as a success criterion.

## 2. Obtain array resources

The workflow requires locally available Illumina resources compatible with the array:

- BPM manifest
- EGT cluster file
- CSV manifest

These files are not distributed in this repository.

The configuration used for development was GSA-24 v3.0 with an A2 BPM and CSV manifest together with the A1 ClusterFile EGT. Compatibility should be established from the resource contents rather than assumed from filename suffixes.

Do not enable relaxed resource checks merely to force apparently incompatible resources through the workflow.

## 3. Obtain the GRCh38 reference

Provide a GRCh38 reference FASTA compatible with the manifest coordinates used for VCF construction.

The validated configuration used the GRCh38 no-alt analysis-set reference.

The reference FASTA should have a corresponding FASTA index (.fai) available. The validated reference was already indexed before the workflow was run.

## 4. Configure the workflow

Copy the example configuration:

    cp config/example_config.sh config/local_config.sh

Edit the local copy to specify:

- BCFTOOLS
- BCFTOOLS_PLUGINS
- BPM
- EGT
- CSV_MANIFEST
- REFERENCE_FASTA
- GENOME_BUILD
- OUTPUT_DIR
- IDAT2GTC_PRESET
- VCF_TAGS

For the validated workflow:

    GENOME_BUILD="GRCh38"
    IDAT2GTC_PRESET="4"
    VCF_TAGS="GT,GQ,IGC,BAF,LRR,R,THETA"

Local configuration files can contain machine-specific paths and should not be committed to a public repository.

## 5. Define IDAT batches

Create a tab-delimited batch manifest with exactly two columns:

    batch_id    idat_dir

For example:

    batch_01    /path/to/batch_01/idat
    batch_02    /path/to/batch_02/idat

Each IDAT directory should contain paired Green and Red IDAT files for the arrays in that batch.

Batch identifiers may contain letters, numbers, underscores, and hyphens.

## 6. Run

From the repository root:

    ./run_pipeline.sh config/local_config.sh batches.tsv

The runner first validates every batch. Genotype calling does not begin if any batch fails IDAT-pair validation.

The output directory must be new or empty. The workflow intentionally does not implement automatic resume or overwrite behavior.

## 7. Verify outputs

A successful run ends with:

    === PIPELINE COMPLETE ===
    Status: PASS

The final cohort VCF is:

    <OUTPUT_DIR>/cohort/vcf/genotypes.GRCh38.vcf.gz

and its index is:

    <OUTPUT_DIR>/cohort/vcf/genotypes.GRCh38.vcf.gz.csi

Run-level provenance is written under:

    <OUTPUT_DIR>/provenance/

This includes software versions, pipeline settings, resource checksums, and final-output checksums.

QC outputs are written under:

    <OUTPUT_DIR>/cohort/qc/

## Data handling

IDAT, GTC, and VCF files contain individual-level genomic information and should be handled accordingly.

The repository gitignore excludes common genomic-data, array-resource, reference-genome, runtime-output, and local-mapping files. The included public-repository check provides an additional guard against accidentally tracking common genomic file types, but it is not a substitute for reviewing staged files before publication.
