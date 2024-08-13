# Porting modules to `OpenScPCA-nf`

- [Introduction](#introduction)
- [Module file structure](#module-file-structure)
- [Inputs and outputs](#inputs-and-outputs)
- [](#)

## Introduction

## Module file structure

Each analysis module from `OpenScPCA-analysis` should be ported as separate Nextflow module that is contained within a subdirectory within the `modules/` directory.
Module directories should have the same name as the `OpenScPCA-analysis` module from which they are derived, and the primary workflow for the module should be placed in a `main.nf` file within that directory (i.e. `modules/{module-name}/main.nf`).

Each module should also contain a `readme.md` file

Scripts that are called within Nextflow processes should be placed in `modules/{module-name}/resources/usr/bin/` and set to be executable (e.g. `chmod +x myscript.R`).
These scripts will then be invoked directly within processes, so they must contain a `#!` (shebang) line defining the execution environment, such as `#!usr/bin/env Rscript` or `#!usr/bin/env python3`.

Any other files that may be needed within a workflow, such as notebook templates, must be passed as inputs to processes to ensure that the files are properly staged within the execution environment.




## Inputs and outputs

In general, modules should take as input the `sample_ch` channel in the `main` workflow.
Each element of this channel has the following structure: `[sample_id, project_id, file(sample_dir)]`

The final element is a file/path object, and could be passed directly to a Nextflow process to stage all data files for a sample.
However, this is not recommended, as most processes will only require a subset of files, such as only the processed `AnnData` files (and not raw files or `SingleCellExperiment` files).
Instead, the files that will be required for each sample should be selected using the `Utils.getLibraryFiles()` function, which will return a list of file paths within a sample directory for a specific type of file.
Note that for some samples, there will be more than one library, so any process that uses this as input should be able to handle multiple libraries.

If the module workflow creates files as output that might be used by other modules, these files should be "emitted" as a new channel with the following structure: `[sample_id, project_id, output_files]` where `output_files` is either a single file per sample or a list of files with one file per library.
If the workflow only emits files at the project level, `[project_id, output_files]` can be used.
Where possible, individual output files should contain the `SCPCS` sample id or `SCPCL` library id to facilitate searching and filtering.

##
