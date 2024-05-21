#!/bin/bash

set -u

GITHUB_TAG=${GITHUB_TAG:-main}

date=$(date "+%Y-%m-%d")
datetime=$(date "+%Y-%m-%dT%H%M")

cd /opt/nextflow
nextflow pull AlexsLemonade/OpenScPCA-nf -r $GITHUB_TAG

nextflow run AlexsLemonade/OpenScPCA-nf \
  -r $GITHUB_TAG \
  -profile batch \
  -entry test \
  -with-report ${datetime}_test_report.html \
  -with-trace  ${datetime}_test_trace.txt

cp .nextflow.log ${datetime}_test.log

# Copy logs to S3 and delete if successful
aws s3 cp . s3://openscpca-nf-data/logs/test/${date} \
  --recursive \
  --exclude "*" \
  --include "${datetime}_*" \
  && rm ${datetime}_*
