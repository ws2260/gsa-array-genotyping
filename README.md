# gsa-array-genotyping

A reproducible workflow for converting Illumina Infinium Global Screening Array (GSA) IDAT files into quality-controlled GRCh38 VCF files using the open-source bcftools idat2gtc and gtc2vcf plugins.

The workflow preserves GTC files as an intermediate, records software and resource provenance, retains genotype- and intensity-related FORMAT fields, and generates sample- and locus-level QC summaries.

## Workflow

IDAT files are processed through the following stages:

    IDAT
      -> Red/Green pair validation
      -> genotype calling with idat2gtc
      -> GTC
      -> GTC-to-VCF conversion with gtc2vcf
      -> coordinate sorting and indexing
      -> sample- and locus-level QC
      -> provenance and checksum capture

Multiple IDAT batches can be called independently and assembled into a single cohort VCF while retaining batch-specific GTC files and logs.

This repository provides workflow orchestration, QC, and reproducibility checks around existing open-source tools. It does not implement a new genotype-calling algorithm.

## Validated configuration

Development and regression testing used:

- Illumina Global Screening Array GSA-24 v3.0
- GSA-24v3-0 A2 BPM
- GSA-24v3-0 A2 CSV manifest
- GSA-24v3-0 A1 ClusterFile EGT
- GRCh38 no-alt analysis-set reference FASTA
- bcftools 1.24 / htslib 1.24
- idat2gtc 2026-01-26
- gtc2vcf 2026-01-26

The A2 BPM and A1 EGT resources used during development contained 654,027 matching marker names. Resource compatibility should be validated from content rather than inferred from filename suffixes alone.

The workflow explicitly uses idat2gtc preset 4. It does not enable allow-missing-clusters or post hoc cluster adjustment.

## Validation

The original interactive IDAT-to-GTC command from the analysis that motivated this workflow was not retained. It was reconstructed from the software version, Illumina resources, processing logs, plugin interface, and resulting outputs. The historical GTC-to-VCF command was independently recovered from the VCF header.

For one validation array, the reconstructed IDAT-to-GTC workflow followed by identical GTC-to-VCF conversion reproduced genotype calls at all 653,817 emitted GRCh38 records from the historical GTC. GQ and GenCall confidence (IGC) values were also identical. The reconstructed and historical GTC files were not byte-identical.

The complete public workflow was subsequently tested end-to-end on one array and produced 653,817 GRCh38 records together with the expected QC and provenance outputs.

These results validate the tested configuration; they should not be generalized to every Illumina array design or resource combination.

## Requirements

The workflow requires:

- paired Green and Red IDAT files;
- a compatible BPM manifest;
- a compatible EGT cluster file;
- the corresponding CSV manifest;
- a GRCh38 reference FASTA; and
- bcftools with the idat2gtc and gtc2vcf plugins available.

Illumina resource files and genomic data are not distributed with this repository.

See INSTALLATION.md for software setup.

## Running the workflow

Copy the example configuration and edit it for the local environment:

    cp config/example_config.sh config/local_config.sh

Batch input directories are supplied through a tab-delimited manifest following config/example_batches.tsv.

Then run:

    ./run_pipeline.sh config/local_config.sh batches.tsv

The runner validates all IDAT batches before genotype calling begins and requires a fresh output directory.

## Major outputs

The final joint VCF is:

    cohort/vcf/genotypes.GRCh38.vcf.gz

The default retained FORMAT fields are:

    GT,GQ,IGC,BAF,LRR,R,THETA

The workflow also generates:

- batch-specific GTC files and processing logs;
- sample-level VCF call-rate summaries;
- locus-level missingness summaries;
- software and pipeline-setting provenance;
- SHA-256 checksums for genotype-calling resources; and
- SHA-256 checksums for the final VCF and its index.

The VCF-level call rate is calculated over emitted VCF records and should not be assumed to equal the call rate reported during GTC generation, because the two stages may use different locus universes.

The QC summaries are descriptive. The workflow does not impose arbitrary sample- or locus-level call-rate filtering thresholds.

## Important limitations

This is an SNP-array workflow, not a sequencing workflow. Only variants represented by the array assays and successfully processed by the calling workflow can be assessed.

A reference genotype does not imply absence of other variation in a gene, and a negative array-based screen does not exclude a genetic disorder, disease-predisposition allele, or other clinically relevant variant.

Array-derived findings intended for biological or clinical interpretation should be evaluated together with probe performance, genotype quality, population frequency, phenotype, and other relevant evidence. Findings with clinical implications require appropriate orthogonal confirmation.

No participant genomic data are included in this repository.

## Downstream analysis

The resulting VCF can be used for downstream annotation, imputation, association analysis, sample demultiplexing, or targeted variant screening as appropriate. Genotype calling and biological interpretation are intentionally kept separate so that upstream technical provenance can be evaluated independently.

## Attribution

This workflow relies on the open-source idat2gtc and gtc2vcf bcftools plugins developed by the freeseek project. Users should cite the underlying software as requested by that project in addition to citing this workflow where appropriate.

## Status

The current workflow has been regression-tested with the configuration described above. Benchmarking against Illumina DRAGEN Array is planned but has not yet been completed.

See docs/methods.md for methodological and validation details.
