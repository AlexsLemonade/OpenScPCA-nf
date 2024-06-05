# OpenScPCA-nf

A workflow for running analysis modules ported from the [OpenScPCA-analysis repository](https://github.com/AlexsLemonade/OpenScPCA-analysis) to [Nextflow](https://www.nextflow.io).

See https://github.com/AlexsLemonade/OpenScPCA-admin/blob/main/technical-docs/nextflow-workflow-specifications.md for initial implementation plans for this workflow.

## Running the workflow

The workflow is currently set up to run best via AWS batch, but some testing may work locally.
You will need to have appropriate AWS credentials set up to run the workflow on AWS and access the data files.

### Running the workflow manually

Alternatively, you can run the workflow locally.
The following base command will run the main workflow, assuming all AWS permissions are set up correctly:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch
```

For most use cases you will want to use the `--results_bucket` argument to avoid writing to the default output bucket.
Note that despite the name, this can be a local directory as well as an S3 bucket.
For an S3 bucket, the format should be `s3://bucket-name/path/to/results`.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch --results_bucket {OUTDIR}
```

### Profiles

To run the workflow with simulated data, you can add the `simulated` profile.
As with the main workflow, you will want to specify an output directory for the simulated results with the `--results_bucket` argument.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch,simulated --results_bucket {SIM_RESULTS_DIR}
```

### Entry points

The workflow also has a couple of entry points other than the main workflow, for testing and creating simulated data.

To run a test version of the workflow to check permissions and infrastructure setup:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch -entry test
```

To run the workflow that creates simulated SCE objects for the OpenScPCA project, you can use the following command, which specifies running the workflow with the `simulate` entry point.
Note that you will need to specify the directory for the simulation output using the `--sim_pubdir` argument, as the default output bucket is not writeable except by a few specific roles:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch -entry simulate --sim_pubdir {SIMDIR}
```

### Stub runs

All of the above commands will run the complete workflow processes.
To test the general logic of the workflow without running the full workflow you can use a stub run by including the `-stub` argument and `-profile stub`.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -stub -profile stub
```

This version of the workflow is run for every pull request to the `main` branch.

## Repository setup

This repository uses [`pre-commit`](https://pre-commit.com) to enforce code style and formatting.
To install the pre-commit hooks described in `.pre-commit-config.yaml`, run the following command in the repository root:

```bash
pre-commit install
```
