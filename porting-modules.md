# Porting modules to `OpenScPCA-nf`

- [Introduction](#introduction)
- [Module directory structure](#module-directory-structure)
- [Inputs and outputs](#inputs-and-outputs)
  - [Input](#input)
  - [Output](#output)
- [](#)

## Introduction

## Module directory structure

Each analysis module from `OpenScPCA-analysis` should be ported as separate Nextflow module that is contained within a subdirectory within the `modules/` directory.
Module directories should have the same name as the `OpenScPCA-analysis` module from which they are derived, and the primary workflow for the module should be placed in a `main.nf` file within that directory (i.e. `modules/{module-name}/main.nf`).

Each module should also contain a `readme.md` file.

Scripts that are called within Nextflow processes should be placed in `modules/{module-name}/resources/usr/bin/` and set to be executable (e.g. `chmod +x myscript.R`).
These scripts will then be invoked directly within processes, so they must contain a `#!` (shebang) line defining the execution environment, such as `#!usr/bin/env Rscript` or `#!usr/bin/env python3`.

Any other files that may be needed within a workflow, such as notebook templates, must be passed as inputs to processes to ensure that the files are properly staged within the execution environment.

## Inputs and outputs

### Input

In general, modules should take as input the `sample_ch` channel in the `main` workflow.
Each element of this channel has the following structure: `[sample_id, project_id, file(sample_dir)]`

The final element is a file/path object, and could be passed directly to a Nextflow process to stage all data files for a sample.
However, this is not recommended, as most processes will only require a subset of files, such as only the processed `AnnData` files (and not raw files or `SingleCellExperiment` files).
Instead, the files that will be required for each sample should be selected using the `Utils.getLibraryFiles()` function, which will return a list of file paths within a sample directory for a specific level of processing (similar to the `download.data.py` script in `OpenScPCA-analysis`).

An example of the of the `Utils.getLibraryFiles()` function in use is shown below, selecting all processed `SingleCellExperiment` files for each sample:

```groovy
sample_ch.map { sample_id, project_id, sample_dir ->
    def processed_files = Utils.getLibraryFiles(sample_dir, format: "sce", process_level: "processed")
    return [sample_id, project_id, processed_files]
}
```

Note that the return value for `Utils.getLibraryFiles()` is always a list, as it is possible to have more than one library file for each sample.
Any nextflow process that uses this as an input element should be able to handle multiple libraries.


### Output

If the module workflow creates files as output that might be used by other modules, these files should be "emitted" as a new channel with the following structure: `[sample_id, project_id, output_files]` where `output_files` is either a single file per sample or a list of files with one file per library.
If the workflow emits results at the project level, `[project_id, output_files]` can be used.

If multiple output files are created by a module (e.g., a table of results and an R object with more detailed output), the same general format should be followed, but with additional entries in each channel element: `[sample_id, project_id, output_files_1, output_files_2, ...]`.

Where possible, individual output files should contain the `SCPCS` sample id, `SCPCL` library id, or `SCPCP` project id, as appropriate, to facilitate searching and filtering.

##
