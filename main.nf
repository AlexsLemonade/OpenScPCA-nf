#!/usr/bin/env nextflow

// **** Included processes from modules ****
include { example } from './modules/example'
include { simulate_sce } from './modules/simulate-sce'
include { merge_sce } from './modules/merge-sce'
include { detect_doublets } from './modules/doublet-detection'

// **** Parameter checks ****
param_error = false

// Set data release path
if (!params.release_bucket) {
  log.error("Release bucket not specified")
  param_error = true
}

def release_dir = Utils.getReleasePath(params.release_bucket, params.release_prefix)

if (!release_dir.exists()) {
  log.error "Release directory does not exist: ${release_dir}"
  param_error = true
}

if (param_error) {
  System.exit(1)
}

workflow test {
  example()
}

workflow simulate {
  project_ids = params.project?.tokenize(';, ') ?: []
  run_all = project_ids.isEmpty() || project_ids[0].toLowerCase() == 'all'

  project_ch = Channel.fromList(Utils.getProjectTuples(release_dir))
    .filter{ run_all || it[0] in project_ids }
  simulate_sce(project_ch)
}

// **** Main workflow ****
workflow {
  project_ids = params.project?.tokenize(';, ') ?: []
  run_all = project_ids.isEmpty() || project_ids[0].toLowerCase() == 'all'

  // sample channel of [sample_id, project_id, sample_path]
  sample_ch = Channel.fromList(Utils.getSampleTuples(release_dir))
    .filter{ run_all || it[1] in project_ids }

  //merge_sce(sample_ch)

  detect_doublets(sample_ch)
}
