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
          path(processed_file),
          val(output_file)
  output:
     tuple val(sample_id), path(output_file)
  script:
    """
    ./run_scdblfinder.R \
      --input_sce_file "${processed_file}" \
      --output_file "${output_file}" \
      --random_seed 2024 \
      --cores ${task.cpus}
    """
  stub:
    """
    touch ${output_file}
    """
}



workflow detect_doublets {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:

    libraries_ch = sample_ch
      // create [sample_id, project_id, [list, of, processed, files]]
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        return [sample_id, project_id, library_files]
      }
      // create [sample_id, project_id, processed file], for all files
      .transpose()
      // create [sample_id, project_id, processed file, output file]
      .map{sample_id, project_id, library_file ->
        def output_file = library_file.name.replaceAll(/(?i).rds$/, "_scdblfinder.tsv")
        return [sample_id, project_id, library_file, output_file]
      }

    // detect doublets
    run_scdblfinder(libraries_ch)
}
