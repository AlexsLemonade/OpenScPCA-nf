# Porting modules to `OpenScPCA-nf`

- [Introduction](#introduction)
- [The `OpenScPCA-nf` default workflow](#the-openscpca-nf-default-workflow)
- [Module structure](#module-structure)
  - [Readme file](#readme-file)
  - [Primary module workflow](#primary-module-workflow)
  - [Processes](#processes)
  - [Executable scripts](#executable-scripts)
  - [Additional module files](#additional-module-files)
- [Module components](#module-components)
  - [Module input (take)](#module-input-take)
    - [The `Utils.getLibraryFiles()` function](#the-utilsgetlibraryfiles-function)
  - [Module output (emit)](#module-output-emit)
  - [Docker images](#docker-images)
  - [Module processes](#module-processes)
    - [Process granularity](#process-granularity)
    - [Process resources](#process-resources)
    - [Stub processes](#stub-processes)

## Introduction

When porting modules from `OpenScPCA-analysis` to `OpenScPCA-nf`, our goal is to require as few changes as possible to the original code, while ensuring that the module can be run as part of a [Nextflow workflow](https://www.nextflow.io/docs/stable/index.html).
We also aim to make each module as modular as possible, with defined inputs and outputs that can be easily connected to other modules as needed.

To that end, we will prioritize using the same scripts and notebooks as are used in the original code when at all possible, with the primary exception being wrapper scripts such as `run_<module-name>.sh` that might be used at the top level of the module in `OpenScPCA-analysis`.

## The `OpenScPCA-nf` default workflow

The default workflow for `OpenScPCA-nf` is contained in the [`main.nf` file](https://github.com/AlexsLemonade/OpenScPCA-nf/blob/main/main.nf) in the root directory of the OpenScPCA-nf repository.

The default workflow is designed to be relatively simple.
It defines channels that modules can use as input (primarily the `sample_ch` channel), and then calls each module workflow, passing the appropriate channel(s) as input.
Any transformations of these channels that may be required by a module should generally take place within the module's workflow, rather than in the default workflow.
If one module requires the output of another module as input, the default workflow will reflect this dependency via the input channels provided to that module containing outputs from a previous module.


## Module structure

Each analysis module from `OpenScPCA-analysis` should be ported as separate [Nextflow module](https://www.nextflow.io/docs/stable/module.html) that is contained within a subdirectory within the `modules/` directory.

- Module directories should have the same name as the `OpenScPCA-analysis` module from which they are derived
- The primary workflow for the module should be placed in a `main.nf` file within the module directory (i.e. `modules/module-name/main.nf`). See [Module workflow file](#module-workflow-file) for more information on the structure of the primary workflow file.
- Each module workflow should be added to the the default workflow using an  [`include` directive](https://www.nextflow.io/docs/stable/module.html#module-inclusion) such as the one below:

```groovy
include { module_name } from './modules/module-name'
```

The module would then be invoked in the default workflow with a statement such as the following:

```groovy
module_name(sample_ch)
```

where `sample_ch` is the channel of samples that is passed to the module (see [Module input](#module-input-take) for more information on the structure of the `sample_ch` channel).

### Readme file

Each module directory should contain a `readme.md` file with the following contents:
 that provides a brief description of the module and its purpose, as well as a link to the original module in `OpenScPCA-analysis`.
This file should also contain permalinks to the original scripts or notebooks from `OpenScPCA-analysis` that are used in the module, as well as descriptions of any additional resources that may be needed to run the module (e.g. reference files, data files, etc.).

### Primary module workflow

The module's primary workflow should be contained in a `main.nf` file within the module directory, and named with the module name (replacing any hyphens with underscores).
For example, for a simple module named `analyze-cells`, the primary workflow file would be `modules/analyze-cells/main.nf`.

### Processes

Most processes should be defined within the module's `main.nf` file, but if a process is particularly complex or requires additional scripts or resources, it may be defined in a separate file within the module directory and added to the module's `main.nf` file with an `include` directive.

### Executable scripts

Scripts that are called within Nextflow processes should be placed in `modules/<module-name>/resources/usr/bin/` and set to be executable (e.g. `chmod +x myscript.R`).
These scripts will then be invoked directly within processes as executables, so they must contain a `#!` (shebang) line defining the execution environment, such as `#!usr/bin/env Rscript` or `#!usr/bin/env python3`.


### Additional module files

Any other files that may be needed within a workflow, such as notebook templates, must be passed as inputs to processes to ensure that the files are properly staged within the execution environment.

## Module components

An example module workflow is shown below:

```groovy
workflow analyze_cells {
  take:
    sample_ch

  main:
    sample_files_ch = sample_ch.map { sample_id, project_id, sample_dir ->
      def processed_files = Utils.getLibraryFiles(sample_dir, format: "sce", process_level: "processed")
      return [sample_id, project_id, processed_files]
    }
    process_1(sample_files_ch)
    process_2(process_1.out)

  emit:
    process_2.out
}
```

This workflow takes the standard `sample_ch` channel as input, selects the processed `SingleCellExperiment` files for each sample, and then passes these files to two processes, `process_1` and `process_2`, emitting the output.


### Module input (take)

In general, module workflows should `take:` as input the `sample_ch` channel that is defined in `OpenScPCA-nf` default workflow.
Each element of this channel has the following structure: `[sample_id, project_id, file(sample_dir)]`

The final element is a file/path object, and could be passed directly to a Nextflow process to stage all data files for a sample.
However, this is not recommended, as most processes will only require a subset of files, such as only the processed `AnnData` files (and not raw files or `SingleCellExperiment` files).
Instead, the files that will be required for each sample should be selected using the [`Utils.getLibraryFiles()` function](#the-utilsgetlibraryfiles-function) or similar methods.


#### The `Utils.getLibraryFiles()` function

The `Utils.getLibraryFiles()` function is designed to create a list of files that are relevant to a particular sample that can be passed as input to a process for proper data staging.

The function takes the following arguments:
- `sample_dir` – The path to the sample directory
- `format:` – The format of the files to be selected (`sce` or `anndata`)
- `process_level:` – The processing level of the files to be selected (`raw`, `filtered` or `processed`)

An example of the `Utils.getLibraryFiles()` function in use is shown below, selecting all processed `SingleCellExperiment` files for each sample:

```groovy
sample_files_ch = sample_ch.map { sample_id, project_id, sample_dir ->
    def processed_files = Utils.getLibraryFiles(sample_dir, format: "sce", process_level: "processed")
    return [sample_id, project_id, processed_files]
}
```

Note that the return value for `Utils.getLibraryFiles()` is always a list, as it is possible to have more than one library file for each sample.
Any Nextflow process that uses the output of this function as an input element should be able to handle multiple library files.


### Module output (emit)

If the module workflow outputs files that other modules might use, these files should be "emitted" as a new channel with the following structure: `[sample_id, project_id, output_files]` where `output_files` is either a single file per sample or a list of files with one file per library.
If the workflow emits results at the project level, `[project_id, output_files]` can be used.

If multiple output files are created by a module (e.g., a table of results and an R object with more detailed output), the same general format should be followed, but with additional entries in each channel element: `[sample_id, project_id, output_files_1, output_files_2, ...]`.

Where possible, individual output files should contain the `SCPCS` sample id, `SCPCL` library id, or `SCPCP` project id as appropriate to facilitate searching and filtering.

### Docker images

Each process should run in a Docker container, usually the image defined in `OpenScPCA-analysis` for the module, which will be available on the [AWS Public ECR](https://gallery.ecr.aws/openscpca/).

All Docker image names should be defined as parameters in the `config/containers.config` file, and referenced in the process definitions with the [`container` directive](https://www.nextflow.io/docs/stable/process.html#container).
Each image should be defined with a version tag to ensure that the images used is consistent across runs of the workflow (though `latest` is acceptable during development).

### Module processes

#### Process granularity

There are no hard and fast rules about how granular each process should be, as we want to balance workflow complexity with flexibility and runtime efficiency.

Some things to consider when defining processes are:

- How long will the process take to run?
If a process is long running with multiple steps, it may be worth breaking into multiple processes to allow for saving on intermediate outputs and to allow for more efficient resource allocation.
- How much processing power is required?
If one step of a workflow requires more CPU or memory than other steps, it may be useful to break that step out so it can be given the resources it needs while other steps can run on lower-resource nodes.
- How useful are intermediate files?
If intermediate files are going to be useful for other analyses, it is better to have a separate process that emits those files as output.
On the other hand, if intermediate files are only useful within the context of the module, it may be more efficient to have a single process with multiple steps where only the final output is emitted.

#### Process resources

By default, each process is given 4 GB of memory and 1 CPU.
Any additional resource requirements should be defined with [`label` directives](https://www.nextflow.io/docs/stable/process.html#label) in the process definition.
Available labels are defined in `config/process_base.config`, and separate labels are used for memory and CPU requirements.

For example, to request 16 GB of memory and 4 CPUs, the process definition would include the following:

```groovy
process my_process {
    label 'mem_16'
    label 'cpus_4'
    ...
}
```

If an instance of a process fails, the memory requirements are automatically increased on the second and third attempts, but the general goal should be for each process successfully complete the majority of samples with the assigned resources.

#### Stub processes

Every process should include a [`stub` section](https://www.nextflow.io/docs/stable/process.html#stub) that uses only basic `bash` commands to create (usually empty) output files that mirror the expected output of the process.
This stub process will be used for initial testing to ensure the overall logic of the workflow is valid.
Note that stub processes are not run in the process container, so they should only include commands that are common to `bash` environments, such as `touch`, `mkdir`, `echo`, etc.
