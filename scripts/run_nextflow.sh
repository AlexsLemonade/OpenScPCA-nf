#!/bin/bash
set -u

# Run the OpenScPCA Nextflow pipeline with options to specify the run mode
# Available run modes are:
#   test:      run the test workflow only
#   simulated: run the main workflow with simulated data
#   scpca:     run the main workflow with real data from ScPCA
#   full:      run the data simulation workflow,
#              followed by the main pipeline with both simulated and real data

GITHUB_TAG=${GITHUB_TAG:-main}
RUN_MODE=${RUN_MODE:-test}

profile="batch"
date=$(date "+%Y-%m-%d")
datetime=$(date "+%Y-%m-%dT%H%M")

cd /opt/nextflow
nextflow pull AlexsLemonade/OpenScPCA-nf -revision $GITHUB_TAG

# test mode runs the test workflow only, then exits
if [ "$RUN_MODE" == "test" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -entry test \
    -profile $profile \
    -with-report ${datetime}_test_report.html \
    -with-trace  ${datetime}_test_trace.txt

  cp .nextflow.log ${datetime}_test.log

  # Copy logs to S3 and delete if successful
  aws s3 cp . s3://openscpca-nf-data/logs/${RUN_MODE}/${date} \
    --recursive \
    --exclude "*" \
    --include "${datetime}_*" \
    && rm ${datetime}_*
  exit 0
fi

# for full mode, run the data simulation pipeline first
if [ "$RUN_MODE" == "full" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -entry simulate \
    -profile $profile \
    -with-report ${datetime}_simulate_report.html \
    -with-trace  ${datetime}_simulate_trace.txt

  cp .nextflow.log ${datetime}_simulate.log
fi

# if simulated or full, run the main pipeline with simulated data
if [ "$RUN_MODE" == "simulated" ] || [ "$RUN_MODE" == "full" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -profile "${profile},simulated" \
    -with-report ${datetime}_simulated_report.html \
    -with-trace  ${datetime}_simulated_trace.txt

  cp .nextflow.log ${datetime}_simulated.log
fi



#if scpca or full, run the main pipeline with real data
if [ "$RUN_MODE" == "scpca" ] || [ "$RUN_MODE" == "full" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -profile profile \
    -with-report ${datetime}_scpca_report.html \
    -with-trace  ${datetime}_scpca_trace.txt

  cp .nextflow.log ${datetime}_scpca.log
fi

# Copy logs to S3 and delete if successful
aws s3 cp . s3://openscpca-nf-data/logs/${RUN_MODE}/${date} \
  --recursive \
  --exclude "*" \
  --include "${datetime}_*" \
  && rm ${datetime}_*
