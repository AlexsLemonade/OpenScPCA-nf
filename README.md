# OpenScPCA-nf

A workflow for running analysis modules ported from the [OpenScPCA-analysis repository](https://github.com/AlexsLemonade/OpenScPCA-analysis) to [Nextflow](https://www.nextflow.io).

See https://github.com/AlexsLemonade/OpenScPCA-admin/blob/main/technical-docs/nextflow-workflow-specifications.md for initial implementation plans for this workflow.

## Running the workflow

The workflow is currently set up to run best via AWS batch, but some testing may work locally.
You will need to have appropriate AWS credentials set up to run the workflow on AWS and access the data files.
Further instructions for this will be added in the future, and we expect this to be run via a GitHub Action for most use cases.

The following base command will run the workflow, assuming all AWS permissions are set up correctly:

```bash
nextflow run alexslemonade/openscpca-nf -profile batch
```

The workflow also has a couple of entry points other than the main workflow, for testing and creating simulated data.

To run a test version the workflow to check permissions and infrastructure setup:

```bash
nextflow run alexslemonade/openscpca-nf -profile batch -entry test
```

To run the workflow that creates simulated SCE objects for the OpenScPCA project, you can use the following command:

```bash
nextflow run alexslemonade/openscpca-nf -profile batch -entry simulate
```

## Repository setup

This repository uses [`pre-commit`](https://pre-commit.com) to enforce code style and formatting.
To install the pre-commit hooks described in `.pre-commit-config.yaml`, run the following command in the repository root:

```bash
pre-commit install
```
