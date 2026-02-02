# Release notes for OpenScPCA-nf

This document contains release notes for versioned releases of the OpenScPCA-nf workflow.

<!--
Add new release notes in reverse numerical order (newest first) below this comment

You may want to add temporary notes here for tracking as features are added, before a new release is ready.
-->

## v0.1.7

All reference files and containers from `OpenScPCA-analysis` have been updated to use the `v0.2.4` tag.
The only change is an update to the reference file used for the `cell-type-consensus` module to now assign a consensus cell type when two of the three automated cell type methods (`SingleR`, `CellAssign`, and `SCimilarity`) agree, but the third method is unable to classify a cell.

## v0.1.6

- All reference files and containers from `OpenScPCA-analysis` use the `v0.2.3` tag
- Two new modules:
  - `cell-type-neuroblastoma-04`: Assigns cell types to Neuroblastoma samples in SCPCP000004
  - `cell-type-scimilarity`: Assigns cell types to all samples using [`SCimilarity`](https://genentech.github.io/scimilarity/index.html)
  - `export-annotations`: Exports annotations from cell typing modules in a standard format for use with `scpca-nf`
- One module has been updated:
  - `cell-type-consensus`:
    - Consensus cell types are now assigned by looking for agreement between `SingleR`, `CellAssign`, and `SCimilarity`.
    If 2 of the 3 methods agree, a consensus cell type is assigned.


## v0.1.5

- Default release date for ScPCA data is set to `2025-06-30`
- Update scpcaTools images to v0.4.3 versions
- One new module:
  - `infercnv-gene-order`: Produce gene order files that can be used as input to `inferCNV`
- Two modules have been updated:
  - `merge-sce`:
    - Two bugs were fixed:
      - The `cell_id` column in the merged object `colData` slot is now correctly formatted as `{library id}-{barcode}`
      - Merged object `colData` slots now include consensus cell type annotations in columns `consensus_celltype_annotation` and `consensus_celltype_ontology`
  - `cell-type-ewings`:
    - A bug causing some cells to be incorrectly classified was fixed


## v0.1.4

- Default release date for ScPCA data is set to `2025-03-20`
- One new module:
  - `cell-type-ewings`: Assigns cell types to Ewing sarcoma samples in `SCPCP000015`
- One module has been updated:
  - `cell-type-consensus`:
    - Now uses the consensus cell type reference from [`OpenScPCA-analysis:v0.2.2`](https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/v0.2.2/analyses/cell-type-consensus/references/consensus-cell-type-reference.tsv)
    - Exports gene expression for a set of marker genes in addition to assigned consensus cell types

## v0.1.3

- Two new modules:
  - `seurat-conversion`: converts processed `SingleCellExperiment` objects to `Seurat` objects
  - `cell-type-consensus`: assigns consensus cell type labels
- Default release date for ScPCA data is set to `2024-11-25`
- A `nextflow_schema.json` file defining all workflow parameters is now available
  - Parameters are also validated as part of the main workflow
- The `testing` profile can now be used for local testing of the workflow


## v0.1.2

- Update scpcaTools images to v0.4.1 versions
- Update simulations to match current (v0.8.5) `scpca-nf` output
  - Change reduced dimension names in AnnData output (to `X_pca` and `X_umap`) and updated formatting to match scpca-nf v0.8.5
  - Use new age columns
  - Metadata for simulated data now includes project-specific fields
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
