#!/bin/bash

set -u

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
    -entry test \
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

# for simulated mode, run the data simulation pipeline first
if [ "$RUN_MODE" == "simulated" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -entry simulate \
    -profile $profile \
    -with-report ${datetime}_simulate_report.html \
    -with-trace  ${datetime}_simulate_trace.txt

  cp .nextflow.log ${datetime}_simulate.log
  # set the profile for the next step to use the simulated data
  profile="${profile},simulated"
fi

# run the default pipeline
nextflow run AlexsLemonade/OpenScPCA-nf \
  -revision $GITHUB_TAG \
  -profile $profile \
  -with-report ${datetime}_report.html \
  -with-trace  ${datetime}_trace.txt

cp .nextflow.log ${datetime}_test.log

# Copy logs to S3 and delete if successful
aws s3 cp . s3://openscpca-nf-data/logs/${RUN_MODE}/${date} \
  --recursive \
  --exclude "*" \
  --include "${datetime}_*" \
  && rm ${datetime}_*
