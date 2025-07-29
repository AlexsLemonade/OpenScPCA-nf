#!/bin/bash
set -u

# Run the OpenScPCA Nextflow pipeline with options to specify the run mode and output
#
# Available RUN_MODE values are:
#   test:      run the test workflow only
#   simulated: run the main workflow with simulated data
#   scpca:     run the main workflow with real data from ScPCA
#   full:      run the data simulation workflow, followed
#              by the main pipeline with both simulated and real data,
#
# OUTPUT_MODE is either `staging` or `prod`, and determines which buckets are used for output
# DATA_RELEASE is the date of the data release to use, in YYYY-MM-DD format, or `default`.

GITHUB_TAG=${GITHUB_TAG:-main}
DATA_RELEASE=${DATA_RELEASE:-default}
RUN_MODE=${RUN_MODE:-test}
OUTPUT_MODE=${OUTPUT_MODE:-staging}
RESUME=${RESUME:-false}

date=$(date "+%Y-%m-%d")
datetime=$(date "+%Y-%m-%dT%H%M")

# Make sure environment includes local bin (where Nextflow is installed)
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Get secrets from AWS Secrets Manager/1Password
AWS_SECRETS=$(aws secretsmanager get-secret-value --secret-id openscpca_service_account_token | jq -r '.SecretString')
# AWS secrets are a key-value store: retrieve individual values with jq
OP_SERVICE_ACCOUNT_TOKEN=$(jq -r '.op_token' <<< "$AWS_SECRETS")
export OP_SERVICE_ACCOUNT_TOKEN
TOWER_ACCESS_TOKEN=$(op read "$(jq -r '.op_seqera_token' <<< "$AWS_SECRETS")")
export TOWER_ACCESS_TOKEN
TOWER_WORKSPACE_ID=$(op read "$(jq -r '.op_seqera_workspace' <<< "$AWS_SECRETS")") # Use the OpenScPCA workspace
export TOWER_WORKSPACE_ID

SLACK_WEBHOOK=$(op read "$(jq -r '.op_slack_webhook' <<< "$AWS_SECRETS")")
export SLACK_WEBHOOK

slack_error() {
  # function to create a slack message from an error log
  log_file=$1
  # add header and bullet points to the log file
  message=$(printf "⚠️ Errors running OpenScPCA-nf pipeline:\n\n"; sed -e 's/^/• /' < "$log_file")
  jq -n --arg message "$message" \
    '{text: "Error running OpenScPCA-nf workflow.",
      blocks: [{
        type: "section",
        text: {
          type: "mrkdwn",
          text: $message
        }
      }]
    }' \
    | curl --json @- "$SLACK_WEBHOOK"
}

# move to nextflow app directory
cd /opt/nextflow || {
  cat "Could not change directory to /opt/nextflow" > run_errors.log
  slack_error run_errors.log
  exit 1
}
# create an empty log file to capture any errors
cat /dev/null > run_errors.log

# Define Nextflow profiles based on output mode
profile="batch"
sim_profile="${profile},simulated"
# Add prod profiles if output is set to prod
if [ "$OUTPUT_MODE" == "prod" ]; then
  sim_profile="${profile},prod_simulated"
  profile="${profile},prod"
fi

# Set the release_prefix param if data release is not default
release_param=""
if [ "$DATA_RELEASE" != "default" ]; then
  # check release is valid
  if [ "$(aws s3 ls "s3://openscpca-data-release/${DATA_RELEASE}")" ]; then
    release_param="--release_prefix $DATA_RELEASE"
  else
    echo "Data release '$DATA_RELEASE' not found in S3" >> run_errors.log
  fi
fi

if [ "$RESUME" == "true" ]; then
  resume_flag="-resume"
else
  resume_flag=""
fi

nextflow pull AlexsLemonade/OpenScPCA-nf -revision $GITHUB_TAG \
|| echo "Error pulling OpenScPCA-nf workflow with revision '$GITHUB_TAG'" >> run_errors.log

# post any errors from from data release and workflow pull and exit
if [ -s run_errors.log ]; then
  slack_error run_errors.log
  exit 1
fi

# test mode runs the test workflow only, then exits
if [ "$RUN_MODE" == "test" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -entry test \
    -profile $profile \
    -with-report "${datetime}_test_report.html" \
    -with-trace  "${datetime}_test_trace.txt" \
    -with-tower \
  || echo "Error with test run" >> run_errors.log

  cp .nextflow.log "${datetime}_test.log"

  # replace any instances of TOWER_ACCESS_TOKEN in logs with masked value
  sed -i "s/${TOWER_ACCESS_TOKEN}/<TOWER_ACCESS_TOKEN>/g" ./*.log*

  # Copy logs to S3 and delete if successful
  aws s3 cp . "s3://openscpca-nf-data/logs/${RUN_MODE}/${date}" \
    --recursive \
    --exclude "*" \
    --include "${datetime}_*" \
    && rm "${datetime}_*" \
    || echo "Error copying logs to S3" >> run_errors.log

  # post errors to slack if there are any
  if [ -s run_nextflow_errors.log ]; then
    slack_error run_errors.log
    exit 1
  else
    exit 0
  fi
fi

# for full mode or simulate only, run the data simulation pipeline
if [ "$RUN_MODE" == "full" ] || [ "$RUN_MODE" == "simulate-only" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -entry simulate \
    -profile $profile \
    -with-report "${datetime}_simulate_report.html" \
    -with-trace  "${datetime}_simulate_trace.txt" \
    -with-tower \
    $resume_flag \
    $release_param \
    || echo "Error with simulate run" >> run_errors.log

  cp .nextflow.log "${datetime}_simulate.log"
fi

# if simulated or full, run the main pipeline with simulated data
if [ "$RUN_MODE" == "simulated" ] || [ "$RUN_MODE" == "full" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -profile $sim_profile \
    -with-report "${datetime}_simulated_report.html" \
    -with-trace  "${datetime}_simulated_trace.txt" \
    -with-tower \
    $resume_flag \
    || echo "Error with simulated data run" >> run_errors.log

  cp .nextflow.log "${datetime}_simulated.log"
fi



#if scpca or full, run the main pipeline with real data
if [ "$RUN_MODE" == "scpca" ] || [ "$RUN_MODE" == "full" ]; then
  nextflow run AlexsLemonade/OpenScPCA-nf \
    -revision $GITHUB_TAG \
    -profile $profile \
    -with-report "${datetime}_scpca_report.html" \
    -with-trace  "${datetime}_scpca_trace.txt" \
    -with-tower \
    $resume_flag \
    $release_param \
    || echo "Error with scpca data run" >> run_errors.log

  cp .nextflow.log "${datetime}_scpca.log"
fi

# replace any instances of TOWER_ACCESS_TOKEN in logs with masked value
sed -i "s/${TOWER_ACCESS_TOKEN}/<TOWER_ACCESS_TOKEN>/g" ./*.log*

# Copy logs to S3 and delete if successful
aws s3 cp . "s3://openscpca-nf-data/logs/${RUN_MODE}/${date}" \
  --recursive \
  --exclude "*" \
  --include "${datetime}_*" \
  && rm ${datetime}_* \
  || echo "Error copying logs to S3" >> run_errors.log

# Post any errors to slack
if [ -s run_errors.log ]; then
  slack_error run_errors.log
  exit 1
else
  exit 0
fi
