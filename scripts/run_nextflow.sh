#!/bin/bash

date=$(date "+%Y-%m-%d")
datetime=$(date "+%Y-%m-%dT%H%M")

cd /opt/nextflow
nextflow run main.nf \
  -profile batch \
  -entry test \
  -with-report ${datetime}_test_report.html \
  -with-trace  ${datetime}_test_trace.txt

cp .nextflow.log ${datetime}_test.log

# Copy logs to S3 and delete if successful
aws s3 cp . s3://openscpca-nf-data/logs/${date} \
  --recursive \
  --exclude "*" \
  --include "${datetime}_*" \
  && rm ${datetime}_*
