# Changelog

All notable changes to this project will be documented in this file.

## 0.1.0

Initial public release.

- Added reproducible multi-batch IDAT-to-GTC processing using the bcftools idat2gtc plugin.
- Added IDAT Green/Red pair validation before genotype calling.
- Added explicit idat2gtc preset 4 configuration for the validated workflow.
- Added cohort assembly with duplicate-GTC detection and local source provenance.
- Added GRCh38 GTC-to-VCF conversion using the bcftools gtc2vcf plugin.
- Retained GT, GQ, IGC, BAF, LRR, R, and THETA by default.
- Added VCF sorting, indexing, and sample-count validation.
- Added descriptive sample-level call-rate and locus-level missingness QC.
- Added software, settings, resource-checksum, and final-output provenance.
- Added public-repository safeguards for common genomic and array-resource files.
- Added documentation of the reconstructed historical workflow and one-array reproducibility validation.

The finalized public runner has been regression-tested end-to-end on one array. Benchmarking against Illumina DRAGEN Array remains planned.
