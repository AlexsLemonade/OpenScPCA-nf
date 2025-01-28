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


### Running the workflow manually

Alternatively, manual launches of the GHA workflow can be triggered by a [`workflow_dispatch` trigger](https://github.com/AlexsLemonade/OpenScPCA-nf/actions/workflows/run-batch.yml), which will allow you to specify specific run and output modes.

When launching manually, you can specify a specific branch or tag to run, but you need to specify this in the _second_ input field, "Branch or tag of workflow to run", not the dropdown menu in the first field, which _must_ be set to `main`.

You can also specify the data release date you want to use as input, as well as the run mode and output mode.

The run modes available are:

- `test`: runs only a simple test workflow to check configuration
- `simulate-only`: runs the workflow to create simulated output data
- `simulated`: runs the workflow using simulated data
- `scpca`: runs the workflow using the current ScPCA data release (does not simulate data)
- `full`: simulates data based on the current ScPCA data release, then runs the workflow using the simulated data *and* current ScPCA data release (this is same as the behavior of the automatic release workflow)

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
You can log in to this instance to monitor _and cancel_ the workflow runs using the AWS console.
You will first need to have access to the "workloads" account, then use the AWS console to navigate to the EC2 console and log into the instance via the "Connect" button.
Choose "Session Manager" to connect to the instance in the browser without needing to use a key pair.
The following link should take you to the correct page: [Connect to Nextflow-workload instance](https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#ConnectToInstance:instanceId=i-04337969c2475d6f0).

The `run_nextflow.sh` script is run in a `tmux` session named `nextflow`, so you can attach to this session to monitor the workflow run.
Processes will be running as the `ec2-user` user on the instance.
To attach to the tmux session (if it is still active), run the following command:

```bash
# attach to the `nextflow` tmux session as ec2-user
sudo -u ec2-user tmux a -t nextflow`
```

Note that if the run is complete, the `tmux` session will be closed.

When connected to the `tmux` session and viewing the current log state, you can also cancel the run by pressing `Ctrl-C` in the terminal.
Note that the workflow may take some time to shut down; it is usually best to wait for it to complete a clean shutdown, but you can also repeat the `Ctrl-C` command to force a shutdown if really necessary.

## Running the workflow locally

Alternatively, you can launch the workflow locally, though this is not generally recommended except for testing.

To run an entirely local test run of the workflow, use the following command:

```bash
nextflow run main.nf -profile testing
```

This will run the workflow using the `testing` profile, which will use simulated data (for a single project by default) and the `local` executor, and will write outputs to the `./test` directory.

It is also possible to run the workflow locally using real data, but this is generally not recommended, due to data size.
You can use the `--results_bucket` argument to choose the workflow output location, which, despite the name, can be a local directory.
But if you really want to, the following _should_ work, storing outputs in the specified output directory:

```bash
nextflow run main.nf --results_bucket {OUTDIR}
```
Note that you will need to have the necessary AWS permissions set up to access the full input data, which will likely require setting the `AWS_PROFILE` environment variable and using `aws sso login` to authenticate first.

### Launching runs on AWS Batch from the command line

⚠️The following section is for reference, as Batch runs should be triggered through the GitHub Actions workflow.

The following base command will run the main workflow, executing it on AWS Batch, assuming all AWS permissions are set up correctly:

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch
```

You can use the `--results_bucket` argument to choose the workflow output location.
Note that despite the name, this can be a local directory or an S3 bucket.
For an S3 bucket, the format should be `s3://bucket-name/path/to/results`.

```bash
nextflow run AlexsLemonade/OpenScPCA-nf -profile batch --results_bucket {OUTDIR}
```

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
