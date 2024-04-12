#!/usr/bin/env nextflow

// **** Included processes from modules ****
include { example } from './modules/example'
include { simulate_sce } from './modules/simulate-sce'

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

// **** Main workflow ****
workflow {
  example()
  // project channel of [project_id, project_path]
  // project_ch = Channel.fromPath(Utils.getProjectPaths(release_dir))
  //   .map{[it.name, it]} // name is the directory name, which will be SCPCP000000 format

  // simulate_sce(project_ch)
}
