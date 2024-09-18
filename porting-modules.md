# Porting modules to `OpenScPCA-nf`

- [Introduction](#introduction)
- [Module structure](#module-structure)
  - [Readme file](#readme-file)
  - [Primary workflow file](#primary-workflow-file)
  - [Processes](#processes)
  - [Executable scripts](#executable-scripts)
  - [Additional module files](#additional-module-files)
- [Module inputs and outputs](#module-inputs-and-outputs)
  - [Input](#input)
  - [Output](#output)
- [Module processes](#module-processes)
  - [Containers](#containers)
  - [Process granularity](#process-granularity)
  - [Process resources](#process-resources)
  - [Stub processes](#stub-processes)

## Introduction

When porting modules from `OpenScPCA-analysis` to `OpenScPCA-nf`, our goal is to require as few changes as possible to the original code, while ensuring that the module can be run as part of a Nextflow workflow.
We also aim to make the module as modular as possible, with defined inputs and outputs that can be easily connected to other modules as needed.
To that end, we will prioritize using the the same scripts and notebooks as are used in the original code when at all possible, with the primary exception being wrapper scripts such as `run_<module-name>.sh` that might be used at the top level of the module in `OpenScPCA-analysis`.

## Module structure

Each analysis module from `OpenScPCA-analysis` should be ported as separate Nextflow module that is contained within a subdirectory within the `modules/` directory.
Module directories should have the same name as the `OpenScPCA-analysis` module from which they are derived, and the primary workflow for the module should be placed in a `main.nf` file within that directory (i.e. `modules/module-name/main.nf`).
The primary workflow should also be named with the module name (replacing any hyphens with underscores), so that it can be included in the root workflow via an `include` directive such as the one below:

```groovy
include { module_name } from './modules/module-name'
```

The module would then be invoked in the primary workflow with a statement such as the following:

```groovy
module_name(sample_ch)
```

where `sample_ch` is the channel of samples that is passed to the module.

### Readme file

Each module should contain a `readme.md` file at the root level of the module directory that provides a brief description of the module and its purpose, as well as a link to the original module in `OpenScPCA-analysis`.
This file should also contain permalinks to the original scripts or notebooks from `OpenScPCA-analysis` that are used in the module, as well as descriptions of any additional resources that may be needed to run the module (e.g. reference files, data files, etc.).


### Primary workflow file

The module's primary workflow should be contained in a `main.nf` file within the module directory, and named with the module name (replacing any hyphens with underscores).
For example, for a simple module named `analyze-cells`, the primary workflow file would be `modules/analyze-cells/main.nf` and it might contain the following workflow definition:

```groovy
workflow analyze_cells {
  take:
    sample_ch

  main:
    process_1(sample_ch)
    process_2(process_1.out)

  emit:
    process_2.out
}
```

### Processes

Most processes should be defined within the primary workflow file, but if a process is particularly complex or requires additional scripts or resources, it may be defined in a separate file within the module directory and added to the module's `main.nf` file with an `include` directive.

### Executable scripts

Scripts that are called within Nextflow processes should be placed in `modules/<module-name>/resources/usr/bin/` and set to be executable (e.g. `chmod +x myscript.R`).
These scripts will then be invoked directly within processes as executables, so they must contain a `#!` (shebang) line defining the execution environment, such as `#!usr/bin/env Rscript` or `#!usr/bin/env python3`.

### Additional module files

Any other files that may be needed within a workflow, such as notebook templates, must be passed as inputs to processes to ensure that the files are properly staged within the execution environment.

## Module inputs and outputs

### Input

In general, module workflows should take as input the `sample_ch` channel in the `main` workflow.
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

## Module processes

### Containers

Each process should run in a container, usually the container defined in `OpenScPCA-analysis` for the module that the process is a part of, which will be available on the [AWS Public ECR](https://gallery.ecr.aws/openscpca/).
The container should be defined with a version tag to ensure that the container used is consistent across all runs of the workflow (though `latest` is acceptable during development).

**Question:** Do we want to have a single config file with all container definitions? Defining the container within a module is deprecated, but I am not sure that we really need variables for this since each module will only have a limited number of processes.

### Process granularity

There are no hard and fast rules about how grandular each process should be, as we want to balance the workflow complexity with flexibility and runtime efficiency.
In general, if one step in the module's analysis is particularly long-running or resource-intensive, it may be better to break that step into a separate process, as we can then assign it higher resource requirements while leaving the other steps running in low-resource nodes.
In addition, if the intermediate files from a process are going to be useful for other analyses, it is better to have a separate process that emits those files as output.
If, however, the intermediate files are only useful within the context of the module, and each step is relatively fast, it may be better to have a single process that includes multiple steps where only the final output is emitted.

### Process resources

The default resources for each process are 4 GB of memory and 1 CPU.
Any additional requirements should be defined with `label` directives in the process definition.
Available labels are defined in `config/process_base.config`, and separate labels are used for memory and CPU requirements.
For example, to request 16 GB of memory and 4 CPUs, the process definition would include the following:

```groovy
process my_process {
    label 'mem_16'
    label 'cpus_4'
    ...
}
```

If an instance of a process fails, the memory requirements are automatically increased on the second and third attempts, but the general goal should be to have each process run to completion for the majority of samples with the assigned resources.

### Stub processes

Every process should include a `stub` directive that uses only basic `bash` commands to create (usually empty) output files that mirror the expected output of the process.
This stub process will be used for initial testing to ensure the overall logic of the workflow is valid.
Note that stub processes are not run in the process container, so they should only include commands that are common to `bash` environments, such as `touch`, `mkdir`, `echo`, etc.
