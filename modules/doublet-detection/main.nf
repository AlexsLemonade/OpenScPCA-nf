#!/usr/bin/env nextflow

// Workflow to detect doublets in a SingleCellExperiment object using scDblFinder

params.doublet_detection_container = 'public.ecr.aws/openscpca/doublet-detection:latest'

process run_scdblfinder {
  container params.doublet_detection_container
  tag "${sample_id}"
  publishDir "/Users/sjspielman/ALSF/doublet-detection/${project_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(sample_path),
          val(library_list)
  output:
    val(sample_id)
  script:
    output_dir=file("${sample_id}", type: 'dir')
    """
    for library_id in ${library_list}; do
      Rscript run_scdblfinder.R \
        --input_sce_file "${sample_path}/${library_id}_processed.rds" \
        --results_dir ${output_dir}
    done
    """
  stub:
    output_dir=file("${sample_id}", type: 'dir')
    """
    for library_id in ${library_list}; do
      touch ${output_dir}/${library_id}_scdblfinder.tsv
    done
    """
}



workflow detect_doublets {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:

    // create [sample_id, project_id, sample_path, [list, of, library, ids, in, sample, path]]
    libraries_ch = sample_ch
      .map{ sample_id, project_id, sample_path ->
        def processed_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        def library_ids = processed_files.collect{it.name.replace('_processed.rds', '')}
        return [sample_id, project_id, sample_path, library_ids]
      }

    // detect doublets
    run_scdblfinder(libraries_ch)
}
