# Instructions for Data Lab users running the OpenScPCA-nf workflow

These instructions are intended for Data Lab users with access to the OpenScPCA AWS account who want to run the OpenScPCA-nf workflow.
In general, you must have `workload` access to run the workflow, or the ability to trigger Github Actions in this repository.

## Running the workflow using GitHub Actions

The most common way to run the workflow will be to run the GitHub Action (GHA) responsible for running the workflow.
The GHA is run automatically when a new release tag is created or by manually triggering the workflow.

The GHA that runs the workflow uses the [Batch CodeDeploy workflow](https://github.com/AlexsLemonade/OpenScPCA-nf/actions/workflows/run-batch.yml) to send an AWS CodeDeploy action to the `Nextflow-workload` instance in the OpenScPCA AWS account.
This will launch the Nextflow workflow on AWS Batch by running the the [run_workflow.sh](scripts/run_nextflow.sh) script on the `Nextflow-workload` instance.

The GHA workflow will run automatically when a new release tag is created, which will include the following steps:

1. Run the workflow using the `simulate` entry point to create simulated SCE objects for the OpenScPCA project.
2. Run the main workflow using the simulated data.
3. Run the main workflow using the real ScPCA data.
4. Upload all Nextflow logs, traces, and html run reports to `s3://openscpca-nf-data/logs/full/`, organized by date.

Alternatively, manual launches of the GHA workflow can be triggered by a [`workflow_dispatch` trigger](https://github.com/AlexsLemonade/OpenScPCA-nf/actions/workflows/run-batch.yml), which will allow you to specify specific run and output modes.

The run modes available are:

- `test`: runs only a simple test workflow to check configuration
- `simulated`: runs the workflow using simulated data
- `scpca`: runs the workflow using the current ScPCA data release
- `full`: simulates data based on the current ScPCA data release, then runs the workflow using the simulated data and current ScPCA data release (this is same as the behavior of the automatic release workflow)

By default, the output mode will be set to `staging`, so all outputs will be saved to S3 buckets that are not shared with users and can not overwrite current production data.
With the `prod` output mode, results will be accessible to users.
`prod` output mode should used for versioned releases of the workflow, and when running on new ScPCA data releases.

The following buckets are used for each output mode.

| bucket description         | `staging`                                      | `prod`                                               |
| -------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| simulated test data        | `s3://openscpca-test-data-release-staging`     | `s3://openscpca-test-data-release-public-access`     |
| simulated workflow results | `s3://openscpca-test-workflow-results-staging` | `s3://openscpca-test-workflow-results-public-access` |
| scpca workflow results     | `s3://openscpca-nf-workflow-results-staging`   | `s3://openscpca-nf-workflow-results`                 |

For each run, all Nextflow logs, traces, and html run reports will be uploaded to `s3://openscpca-nf-data/logs/{run_mode}/`, organized by date of the run.

### Monitoring runs

#### Using Seqera Platform

All runs should appear on the Seqera Platform in the OpenScPCA workspace at the following location:
https://cloud.seqera.io/orgs/CCDL/workspaces/OpenScPCA/watch

You must have access to the CCDL workspace to view the runs.

#### Using the Nextflow-workload instance

All runs are launched on the `Nextflow-workload` instance in the OpenScPCA AWS workloads account.
You can log in to this instance to monitor the workflow runs using the AWS console.
The `run_nextflow.sh` script is run in a `tmux` session named `nextflow`, so you can attach to this session to monitor the workflow run.
Processes will be running as the `ec2-user` user on the instance, so to attach to the tmux session (if it is still active), run the following command:

```bash
# attach to the `nextflow` tmux session as ec2-user
sudo -u ec2-user tmux a -t nextflow`
```

Note that if the run is complete, the `tmux` session will be closed.

## Running the workflow manually

Alternatively, you can run the workflow locally.
The following base command will run the main workflow, assuming all AWS permissions are set up correctly:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch
```

You can use the `--results_bucket` argument to choose the workflow output location.
Note that despite the name, this can be a local directory or an S3 bucket.
For an S3 bucket, the format should be `s3://bucket-name/path/to/results`.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch --results_bucket {OUTDIR}
```

### Staging and production profiles

⚠️The following section is for reference, as production runs should be triggered through the GitHub Actions workflow.

By default, the workflow output buckets are set to staging buckets on S3, as described above.
To use the production buckets, you can add the `prod` profile to commands intended to write to the production buckets.
For example, to run the main workflow with the production output buckets, you would use the following command:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch,prod
```

To run with simulated data but output to the production bucket, use the specific `prod_simulated` profile:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch,prod_simulated
```
