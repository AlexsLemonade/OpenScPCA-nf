# Workflow for merging SCE files for a given project

This workflow creates merged SCE files and associated AnnData files from a project's individual SCE files.

The workflow and scripts are largely ported from the [`scpca-nf` workflow](https://github.com/AlexsLemonade/scpca-nf).
The [a9dc826 commit](https://github.com/AlexsLemonade/scpca-nf/tree/a9dc826b8576c48ca38c6ca137f9eeced29c3acc) was used as the base for the port.

There have been some small changes, in particular:

- Containers have been updated to use a more recent version of `scpcaTools`, with underlying updates to Bioconductor and Python packages.
- The workflow is run on a project level, and all SCE files within a project are merged.
  - the assumption in this workflow is that all libraries within a project are to be merged, so there (currently) are no options to specify which specific samples to merge.
  - The `--include_adt` flag was also removed from the `merge_sces.R` script, replaced by looking directly at the SCE objects
  - The `sce_to_anndata.R` script now only warns if the requested feature altExp is not found in the SCE file, rather than erroring out.
