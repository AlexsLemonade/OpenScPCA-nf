# OpenScPCA-nf

A workflow for running analysis modules ported from the [OpenScPCA-analysis repository](https://github.com/AlexsLemonade/OpenScPCA-analysis) to [Nextflow](https://www.nextflow.io).

See https://github.com/AlexsLemonade/OpenScPCA-admin/blob/main/technical-docs/nextflow-workflow-specifications.md for initial implementation plans for this workflow.

## Running the workflow

The workflow is currently set up to run best via AWS batch, but some testing may work locally.
You will need to have appropriate AWS credentials set up to run the workflow on AWS and access the data files.
In general, you must have `workload` access in an OpenScPCA AWS account to run the workflow.

### Running the workflow from GitHub Actions

The most common way to run the workflow will be through GitHub Actions (GHA), using the [Batch CodeDeploy workflow](https://github.com/AlexsLemonade/OpenScPCA-nf/actions/workflows/run-batch.yml).
This will send an AWS CodeDeploy action to the `Nextflow-workload` instance in the OpenScPCA AWS account, which will launch the Nextflow workflow on AWS Batch.
The script that launches the workflow is [run_workflow.sh](scripts/run_nextflow.sh), which is run in a tmux session on the `Nextflow-workload` instance, allowing the workflow to run in the background and be monitored by logging into the instance.

The GHA workflow will run automatically when a new release tag is created, which will include the following steps:

1. Run the `simulate` entry point to create simulated SCE objects for the OpenScPCA project.
2. Run the main workflow using the simulated data.
3. Run the main workflow using the real ScPCA data.
4. Upload all Nextflow logs, traces, and html run reports to `s3://openscpca-nf-data/logs/full/`, organized by date.

Alternatively, manual launches of the GHA workflow can be triggered by a [`workflow_dispatch` trigger](https://github.com/AlexsLemonade/OpenScPCA-nf/actions/workflows/run-batch.yml), which will allow you to specify a specific run mode.
The run modes available are:

- `test`: runs only a simple test workflow to check configuration
- `simulated`: runs the workflow using simulated data
- `scpca`: runs the workflow using the current ScPCA data release
- `full`: simulates data based on the current ScPCA datarelease, then runs the workflow using the simulated data and current ScPCA data release (this is same as the behavior of the automatic release workflow)

For each run, all Nextflow logs, traces, and html run reports will be uploaded to `s3://openscpca-nf-data/logs/{run_mode}/`, organized by date of the run.

### Running the workflow manually

The following base command will run the main workflow, assuming all AWS permissions are set up correctly:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch
```

For most use cases you will want to specify an output directory other than the default using the `--results_bucket` argument.
Note that despite the name, this can be a local directory as well as an S3 bucket.
For an S3 bucket, the format should be `s3://bucket-name/path/to/results/`.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch --results_bucket {OUTDIR}
```

The workflow also has a couple of entry points other than the main workflow, for testing and creating simulated data.

To run a test version of the workflow to check permissions and infrastructure setup:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch -entry test
```

To run the workflow that creates simulated SCE objects for the OpenScPCA project, you can use the following command, but note that you will need to specify directory for the simulation output, as the default bucket is not generally writeable, even with the correct permissions:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch -entry simulate --sim_pubdir {SIMDIR}
```

To run the workflow with simulated data, you can add the `simulated` profile.
As with the main workflow, you will want to specify an output directory for the simulated results with the `--results_bucket` argument.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch,simulated --results_bucket {SIM_RESULTS_DIR}
```

## Repository setup

This repository uses [`pre-commit`](https://pre-commit.com) to enforce code style and formatting.
To install the pre-commit hooks described in `.pre-commit-config.yaml`, run the following command in the repository root:

```bash
pre-commit install
```
