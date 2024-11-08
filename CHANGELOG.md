# Release notes for OpenScPCA-nf

This document contains release notes for versioned releases of the OpenScPCA-nf workflow.

<!--
Add new release notes in reverse numerical order (newest first) below this comment

You may want to add temporary notes here for tracking as features are added, before a new release is ready.
-->

## v0.1.2

- Update scpcaTools images to v0.4.1 versions
- Update simulations to match current (v0.8.5) `scpca-nf` output
  - Change reduced dimension names in AnnData output (to `X_pca` and `X_umap`)
  - Use new age columns
- Centralized docker image definitions in `config/containers.config`
- Added initial documentation about porting modules

## v0.1.1

- Increase default memory for scDblFinder processes

## v0.1.0

- Initial versioned release of the `OpenScPCA-nf` Nextflow workflow
- Current modules:
  - `example`: a very small test module for testing configuration parameters
  - `simulate_sce`: creates simulated and permuted data for testing here and in [`OpenScPCA-analysis`](https://github.com/AlexsLemonade/OpenScPCA-analysis)
  - `merge_sce`: merges multiple datasets into a single SCE object and corresponding AnnData objects
  - `doublet_detection`: runs `scDblFinder` to detect doublets in a dataset
- The default workflow entrypoint currently runs the `merge_sce` and `doublet_detection` modules. Other workflow entrypoints are:
  - `test` to run the `example` module
  - `simulate` to run the `simulate_sce` module
- Includes scripts for running the workflow on AWS batch through Code Deploy
