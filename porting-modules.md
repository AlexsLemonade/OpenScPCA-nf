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
  - [Module parameters](#module-parameters)
  - [Docker images](#docker-images)
    - [Pull-through registry](#pull-through-registry)
  - [Module processes](#module-processes)
    - [Process granularity](#process-granularity)
    - [Process resources](#process-resources)
    - [Stub processes](#stub-processes)
  - [Special considerations for custom cell type annotation modules](#special-considerations-for-custom-cell-type-annotation-modules)

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

Port each analysis module from `OpenScPCA-analysis` as separate [Nextflow module](https://www.nextflow.io/docs/stable/module.html) that is contained within a subdirectory within the `modules/` directory.

- Give module directories the same name as the `OpenScPCA-analysis` module from which they are derived
- Name the primary workflow file for the module `main.nf` file and place it within the module directory (i.e. `modules/module-name/main.nf`).
See [Module components](#module-components) for more information on the structure of the primary workflow file.
- Name the primary workflow within the `main.nf` file with the same name as the module (replacing any hyphens with underscores).
For example, for a module named `analyze-cells`, the primary workflow file would be called `modules/analyze-cells/main.nf` and would contain a workflow called `analyze_cells`.
- Reference the module workflow in the the default workflow file (`OpenScPCA-nf/main.nf`) using an [`include` directive](https://www.nextflow.io/docs/stable/module.html#module-inclusion) such as the one below:

```groovy
include { analyze_cells } from './modules/analyze-cells'
```

Then invoke module workflow from the default workflow with a statement such as the following:

```groovy
analyze_cells(sample_ch)
```

where `sample_ch` is the channel of samples that is passed to the module (see [Module input](#module-input-take) for more information on the structure of the `sample_ch` channel).

### Readme file

Include a `readme.md` file in each module with the following contents:

- A brief description of the module and its purpose
- A link to the module it is derived from in `OpenScPCA-analysis`
- A list of any scripts or notebooks that are used in the module, with permalinks to the original files that they are derived from in `OpenScPCA-analysis`
- Descriptions of any additional resources that may be needed to run the module (e.g. reference files, data files, etc.)

### Primary module workflow

Name the primary workflow for each module with the module name, replacing any hyphens with underscores, and place it in the `main.nf` file within the module directory.
For example, for a module named `analyze-cells`, the primary workflow file would be `modules/analyze-cells/main.nf` and would contain a workflow called `analyze_cells`.

### Processes

Most processes can be defined within the module's `main.nf` file, but if a process is particularly complex or requires additional scripts or resources, you may want to split processes inteo separate files, which can then be added to the module's `main.nf` file with an `include` directive.

### Executable scripts

Place scripts that are called within Nextflow processes in `modules/<module-name>/resources/usr/bin/` and set them to be executable (e.g. `chmod +x my_script.R`).
These scripts will then be invoked directly within processes as executables, so they must contain a `#!` (shebang) line defining the execution environment, such as `#!usr/bin/env Rscript` or `#!usr/bin/env python3`.


### Additional module files

Other files that may be needed within a workflow, such as notebook templates, must be passed as inputs to processes to ensure that the files are properly staged within the execution environment.

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

If a module creates multiple output files (e.g., a table of results and an R object with more detailed output), follow the same general format, but with additional entries in each channel element: `[sample_id, project_id, output_files_1, output_files_2, ...]`.

Where possible, include the `SCPCS` sample id, `SCPCL` library id, or `SCPCP` project id as appropriate in the file name to facilitate searching and filtering.

If the added module adds custom cell type annotations, see the [Special considerations for custom cell type annotation modules](#special-considerations-for-custom-cell-type-annotation-modules) to ensure the output of the module is formatted properly.

### Module parameters

If a module requires additional parameters, these should be defined as entries in the `config/module_parameters.config` file.
You will also need to add them to the `nextflow_schema.json` file, which can be updated using the following command from the root of the repository:

```bash
nf-core pipelines schema build
```

This will launch a web editor to add descriptions, help, and validation rules for the new parameters.

If you do not already have `nf-core` installed, you can use the `environment.yml` file in this repository to create a conda environment with the necessary tools prior to updating the `nextflow_schema.json` file:

```bash
conda env create -n openscpca-nf -f environment.yml
```


### Docker images

Each process should run in a Docker container, usually the image defined in `OpenScPCA-analysis` for the module, which will be available on the [AWS Public ECR](https://gallery.ecr.aws/openscpca/).

Define Docker image names as parameters in the `config/containers.config` file, and reference those in the process definitions with the [`container` directive](https://www.nextflow.io/docs/stable/process.html#container).

Define each image with a version tag to ensure that the images used are consistent across runs of the workflow (though `latest` is acceptable during development).

#### Pull-through registry

For most images, we use a pull-through cache in our AWS account to speed up transfers and image pulls.
To simplify management, we keep the source image name in the containers.config files, and then prepend the pull-through registry address defined in the `params.pullthrough_registry` parameter, if it exists, using the `Utils.pullthroughContainer()` function within the module container directive.
For example, we define the container directive for a process that uses the `python_container` image as follows:

```groovy
container: Utils.pullthroughContainer(params.python_container, params.pullthrough_registry)
```

Setup note:
When setting up the pull through rules, the prefix for each pull-through rule should be defined as the address of the registry with periods replaced by underscores, e.g., `quay_io` for `quay.io`.
At the moment, pull-through is only enabled for images hosted in the AWS Public ECR and quay.io; any other sources will be pulled directly.


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
Define any additional resource requirements with [`label` directives](https://www.nextflow.io/docs/stable/process.html#label) in the process definition.
Available labels are defined in `config/process_base.config`, and separate labels are used for memory and CPU requirements.

For example, to request 16 GB of memory and 4 CPUs, the process definition would include the following:

```groovy
process my_process {
    label 'mem_16'
    label 'cpus_4'
    ...
}
```

If an instance of a process fails, Nextflow will automatically increase the memory requirements on the second and third attempts, but the general goal should be for each process successfully complete the majority of samples with the assigned resources.

#### Stub processes

Include a [`stub` section](https://www.nextflow.io/docs/stable/process.html#stub) for each process that uses only basic `bash` commands to create (usually empty) output files that mirror the expected output of the process.
This stub process is used for initial testing to ensure the overall logic of the workflow is valid.
Note that stub processes are not run in the process container, so they should only include commands that are common to `bash` environments, such as `touch`, `mkdir`, `echo`, etc.

### Special considerations for custom cell type annotation modules

If the module being added includes assigning custom cell type annotations (e.g., `cell-type-ewings` module) and the annotations output from this module will be included in processed objects on the ScPCA Portal, the cell type annotations can be provided as input to the `export-annotations` module.
This module outputs a JSON file for each library containing an array of cell barcodes, array of cell type annotations, array of cell type ontologies, the original module name, workflow release, and data release.
All exported annotations can be found in `s3://openscpca-celltype-annotations-public-access`.

Within the cell typing module, the published output file should be a TSV file with one row for each barcode and column(s) containing any assigned cell type annotations.
The output channel from the module should be properly formatted and provided as input to the `export_annotations()` process in the main workflow.
This includes a tuple of `[sample id, project id, [cell type assignment files], annotation metadata]` where `annotation metadata` is a dictionary containing `module_name`, `annotation_column`, and `ontology_column`.
The `module_name` should correspond to the original module name in `OpenScPCA-analysis`.
The `annotation_column` and `ontology_column` should contain the name of the column within the TSV file containing the annotations to be ported to the objects on the ScPCA Portal.

Below is an example of creating the required module output within the `main.nf` script of the cell type annotation module being added.

```groovy
// add module-specific cell type metadata to output tuple
celltype_output_ch = new_celltyping_module.out
  .map{ sample_id, project_id, assignment_files -> tuple(
    sample_id,
    project_id,
    assignment_files,
    [ // annotation metadata
      module_name: "new-celltyping-module",
      annotation_column: "new_celltype_annotation",
      ontology_column: "new_celltype_ontology"
    ]
  )}

emit:
  celltypes = celltype_output_ch // [sample_id, project_id, [cell type assignment files], annotation_metadata]
```

Then in the main workflow, the output should be mixed with the output from other cell type annotation channels and provided as input to `export_annotations()`.

```groovy
export_ch = cell_type_ewings.out.celltypes
  .mix(cell_type_neuroblastoma_04.out.celltypes)
  .mix(new_celltype_module.out.celltypes) # mix in new module results
export_annotations(export_ch)
```
