#!/usr/bin/env nextflow

// **** Included workflows and processes from modules ****
include { example } from './modules/example'
include { simulate_sce } from './modules/simulate-sce'
include { merge_sce } from './modules/merge-sce'
include { detect_doublets } from './modules/doublet-detection'
include { seurat_conversion } from './modules/seurat-conversion'
include { cell_type_consensus } from './modules/cell-type-consensus'
include { cell_type_ewings } from './modules/cell-type-ewings'

// **** Parameter checks ****
include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'
param_error = false

// Validate input parameters
validateParameters()

// Print summary of supplied parameters
log.info paramsSummaryLog(workflow)

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

// **** Default workflow ****
workflow {
  project_ids = params.project?.tokenize(';, ') ?: []
  run_all = project_ids.isEmpty() || project_ids[0].toLowerCase() == 'all'

  // sample channel of [sample_id, project_id, sample_path]
  sample_ch = Channel.fromList(Utils.getSampleTuples(release_dir))
    .filter{ run_all || it[1] in project_ids }

  // Run the merge workflow
  merge_sce(sample_ch)

  // Run the doublet detection workflow
  detect_doublets(sample_ch)

  // Run the seurat conversion workflow
  seurat_conversion(sample_ch)

  // Run the consensus cell type workflow
  cell_type_consensus(sample_ch)

  // Run the cell type ewings workflow
  // only runs on SCPCP000015
  cell_type_ewings(sample_ch.filter{ it[1] == "SCPCP000015" }, cell_type_consensus.out)
}
