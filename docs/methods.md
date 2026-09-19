# Methods and validation

## Purpose

gsa-array-genotyping provides a reproducible workflow for processing Illumina Infinium Global Screening Array IDAT files into a GRCh38 VCF while retaining genotype-quality and intensity-derived fields useful for technical QC.

The workflow orchestrates the open-source bcftools idat2gtc and gtc2vcf plugins. Genotype calling itself is performed by these upstream tools; this repository provides input validation, batch handling, conversion, QC, and provenance capture around them.

## Workflow design

Processing is divided into five main stages:

1. validation of paired Green and Red IDAT files;
2. IDAT-to-GTC genotype calling within each input batch;
3. assembly of batch GTC files into a cohort;
4. GTC-to-VCF conversion, sorting, and indexing; and
5. sample-level and locus-level VCF QC.

Software versions, pipeline settings, resource checksums, and final-output checksums are recorded separately as run provenance.

GTC files are retained as an explicit intermediate rather than converting directly from IDAT to VCF. This provides a checkpoint between genotype calling and VCF construction and preserves batch-specific calling outputs and logs.

## Validated software and resources

The workflow was developed and regression-tested using:

- bcftools 1.24;
- htslib 1.24;
- idat2gtc 2026-01-26;
- gtc2vcf 2026-01-26;
- Illumina GSA-24 v3.0 A2 BPM;
- Illumina GSA-24 v3.0 A2 CSV manifest;
- Illumina GSA-24 v3.0 A1 ClusterFile EGT; and
- the GRCh38 no-alt analysis-set reference FASTA.

The BPM and EGT resources used for development each represented 654,027 markers, and marker-name comparison showed 654,027 matches. This establishes marker-name compatibility for the tested resource pair; it should not be interpreted as a general rule that A2 BPM and A1 EGT resources are interchangeable.

Resource compatibility is therefore treated as a property of the actual files rather than inferred from filename suffixes.

## IDAT preflight

Each batch is represented by a directory containing paired Green and Red IDAT files.

Before genotype calling, the workflow checks the directory for:

- total IDAT-file count;
- number of array-position identifiers;
- complete Green/Red pairs;
- missing Green files;
- missing Red files;
- duplicate Green files;
- duplicate Red files; and
- filenames that do not match the expected Green/Red pattern.

The public runner performs this preflight for every declared batch before processing any batch. If any batch fails, genotype calling does not begin.

The preflight summary reports aggregate counts and does not intentionally print individual array identifiers.

## IDAT-to-GTC calling

Each validated batch is processed independently with idat2gtc using the configured BPM and EGT resources.

The validated workflow explicitly specifies preset 4, corresponding to the idat2gtc plugin option for emulating Illumina Array Analysis CLI behavior.

The workflow does not enable allow-missing-clusters or other options intended to relax cluster-resource compatibility checks.

Batch-specific GTC files and the idat2gtc execution log are retained.

The number of generated GTC files is compared with the number of complete IDAT pairs, and a mismatch causes the stage to fail.

## Cohort assembly

After all batches have been called successfully, their GTC files are assembled into a cohort directory using symbolic links.

The workflow checks for duplicate GTC basenames across batches before creating cohort links. A collision causes the assembly step to fail rather than silently overwrite or merge files.

A local provenance table records the source batch and source path for each assembled GTC. This table is a runtime artifact and can contain local filesystem information; it is not intended for publication.

Keeping genotype calling batch-specific while performing VCF construction jointly preserves the original batch organization for subsequent technical review.

## GTC-to-VCF conversion

The cohort GTC files are converted with gtc2vcf using the configured BPM, CSV manifest, EGT, reference FASTA, and genome-build label.

The validated workflow retains:

    GT,GQ,IGC,BAF,LRR,R,THETA

The workflow does not enable post hoc cluster adjustment.

For the validated GSA-24 v3.0 resources, gtc2vcf reported:

    manifest records:       654,027
    missing reference:            0
    skipped:                    210
    emitted VCF records:    653,817

The resulting VCF is coordinate-sorted with bcftools and indexed.

The number of VCF samples is checked against the number of cohort GTC inputs.

## VCF QC

QC is calculated from the emitted cohort VCF and is descriptive rather than a hard filtering stage.

### Sample-level call rate

For each sample, VCF call rate is defined as the number of emitted VCF records with a non-missing GT divided by the total number of emitted VCF records.

Missing genotypes include fully or partially missing GT representations.

This VCF-level quantity is intentionally distinguished from the call rate reported during GTC generation. The two values can differ because genotype calling and VCF construction need not use identical locus universes or denominators.

The workflow does not impose a universal sample call-rate threshold.

### Locus-level missingness

For each emitted VCF record, the workflow records:

- chromosome;
- position;
- variant identifier;
- number of samples;
- number called;
- number missing; and
- missing-genotype fraction.

Aggregate summaries include counts of complete loci and loci with missing genotypes at several descriptive percentage levels.

These percentage levels are reporting bins, not automatic filtering thresholds.

### FORMAT fields

The QC stage verifies that the configured FORMAT fields are present in the final VCF.

The retained BAF, LRR, R, and THETA values provide intensity-related information for downstream technical review. No universal thresholds for these fields are imposed by the workflow.

## Provenance

Before genotype calling, the workflow records:

- bcftools version;
- htslib version;
- idat2gtc version;
- gtc2vcf version;
- genome-build setting;
- idat2gtc preset;
- retained VCF FORMAT tags;
- resource filenames;
- cluster-handling settings; and
- SHA-256 checksums for the BPM, EGT, CSV manifest, and reference FASTA.

The tested plugin versions return exit status 255 after displaying help. Plugin-version capture therefore parses the version from the emitted help text and validates that a version was recovered rather than treating the help-command exit status as evidence of plugin failure.

After successful VCF construction and QC, SHA-256 checksums are recorded for the final compressed VCF and its index.

Resource checksum records use resource basenames rather than machine-specific absolute paths. Local paths remain outside the portable run-level provenance.

## Reconstruction of the historical workflow

The workflow was developed while auditing an earlier GSA analysis.

The exact historical interactive IDAT-to-GTC command was not retained. Its configuration was reconstructed from the retained software version, Illumina resource files, execution logs, idat2gtc interface, and resulting data.

The retained logs established use of idat2gtc 2026-01-26, the A2 BPM, the A1 ClusterFile EGT, normalization algorithm version 1.2.0, genotyping algorithm version 7.0.0, and the calling and sex-estimation parameters emitted by the software. Explicit use of preset 4 in the reconstructed workflow reproduced the corresponding historical settings in a validation run.

In contrast, the historical GTC-to-VCF command was recoverable from the VCF header. It used the A2 BPM and CSV manifest, A1 ClusterFile EGT, GRCh38 no-alt analysis-set FASTA, GRCh38 build label, and the FORMAT fields GT,GQ,IGC,BAF,LRR,R,THETA.

This distinction is retained in the documentation: IDAT-to-GTC was reconstructed and experimentally validated, whereas the historical GTC-to-VCF invocation was directly recoverable from output provenance.

## Reconstruction validation

A single array was independently recalled from its original paired IDAT files using the reconstructed IDAT-to-GTC workflow.

The reconstructed call produced the same GTC-level call rate and sex estimate reported in the historical processing log for that array.

The reconstructed and historical GTC files were then independently converted to GRCh38 VCF using the same gtc2vcf resources and options. Both conversions produced 653,817 records.

Across all 653,817 emitted records:

- variant records corresponded one-to-one;
- GT was identical at all records;
- GQ was identical at all records; and
- IGC was identical at all records.

The reconstructed and historical GTC files were not byte-identical. The validation therefore supports reproducibility of the tested genotype calls and the stated quality fields rather than binary identity of the GTC container.

The complete public runner was subsequently tested from a paired IDAT input through GTC generation, cohort assembly, VCF construction, QC, and provenance capture. The end-to-end regression completed successfully with one VCF sample and 653,817 emitted GRCh38 records.

## Interpretation and limitations

The workflow processes SNP-array measurements and should not be interpreted as a sequencing workflow.

Array content limits which loci can be directly assessed. Variants not represented by an informative assay cannot be excluded by a negative array result.

REF and ALT in the resulting VCF describe alleles relative to the reference representation; they do not by themselves encode population major/minor status or pathogenicity.

Likewise, homozygous ALT calls are not inherently rare or pathogenic.

For applications that depend on individual loci, particularly rare or potentially clinically relevant findings, probe-level technical evidence and orthogonal confirmation remain important.

Different downstream applications can tolerate genotype error differently. Analyses based on many common informative markers may be relatively robust to occasional individual-locus errors, whereas rare-variant screening may depend on a single assay. Imputation, phasing, association testing, and other genotype-sensitive analyses should therefore apply QC appropriate to their specific use.

Benchmarking against Illumina DRAGEN Array is planned but was not available during development of the current workflow.
