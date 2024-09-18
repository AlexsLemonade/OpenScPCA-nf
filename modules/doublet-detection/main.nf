#!/usr/bin/env nextflow

// Workflow to detect doublets in a SingleCellExperiment object using scDblFinder

process run_scdblfinder {
  container 'public.ecr.aws/openscpca/doublet-detection:v0.1.0'
  tag "${sample_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/doublet-detection/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
  output:
    tuple val(sample_id),
          val(project_id),
          path(output_files)
  script:
    output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_scdblfinder.tsv")
      }
    """
    for file in ${library_files}; do
      run_scdblfinder.R \
        --input_sce_file \$file \
        --output_file \$(basename \${file%.rds}_scdblfinder.tsv) \
        --random_seed 2024 \
        --cores ${task.cpus}
    done
    """

  stub:
    output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_scdblfinder.tsv")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_scdblfinder.tsv)
    done
    """
}



workflow detect_doublets {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:
    // create [sample_id, project_id, [list of processed files]]
    libraries_ch = sample_ch
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        return [sample_id, project_id, library_files]
      }

    // detect doublets
    run_scdblfinder(libraries_ch)

  emit:
    run_scdblfinder.out // [sample_id, project_id, [list of scdblfinder_output files]]
}
