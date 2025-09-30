#!/usr/bin/env nextflow

// Workflow to convert SCE objects to Seurat objects

process seurat_convert {
  container Utils.pullthroughContainer(params.seurat_conversion_container, params.pullthrough_registry)
  tag "${sample_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/seurat-conversion/${project_id}/${sample_id}", mode: 'copy'
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
        it.name.replaceAll(/(?i).rds$/, "_seurat.rds")
      }
    """
    # convert all files in the working directory, output to the same directory
    convert-to-seurat.R -i . -o .
    """

  stub:
    output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_seurat.rds")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_seurat.rds)
    done
    """
}



workflow seurat_conversion {
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
    seurat_convert(libraries_ch)

  emit:
    seurat_convert.out // [sample_id, project_id, [list of seurat format files]]
}
