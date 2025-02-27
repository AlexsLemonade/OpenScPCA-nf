#!/usr/bin/env nextflow

// Workflow to assign consensus cell type labels

process ewing_aucell {
  container params.cell_type_ewing_container
  tag "${project_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-ewings/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
    val auc_max_rank
    path msigdb_list
    path ews_high_list
    path ews_low_list
  output:
    tuple val(sample_id),
          val(project_id),
          path(aucell_output_files)
  script:
    aucell_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_ewing-aucell-results.tsv.gz")
      }
    // combine the custom gene sets into a single input
    custom_geneset_files = [ews_high_list, ews_low_list].join(",")
    """
    for file in ${library_files}; do
      aucell.R \
        --sce_file \$file \
        --custom_geneset_files ${custom_geneset_files} \
        --msigdb_genesets ${msigdb_list} \
        --max_rank_threshold ${auc_max_rank} \
        --output_file \$(basename \${file%.rds}_ewing-aucell-results.tsv.gz) \
        --threads ${task.cpus} \
        --seed 2025
    done
    """

  stub:
    aucell_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_ewing-aucell-results.tsv.gz")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_ewing-aucell-results.tsv.gz)
    done
    """
}



workflow cell_type_ewings {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:
    // create [sample_id, project_id, [list of processed files]]
    libraries_ch = sample_ch
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        return [sample_id, project_id, library_files]
      }
      // only run on SCPCP000015 with Ewing sarcoma samples
      .filter{ it[1] == "SCPCP000015" }

    // run aucell on ewing gene sets
    ewing_aucell(
      libraries_ch,
      params.cell_type_ewings_auc_max_rank,
      file(params.cell_type_ewings_msigdb_list),
      file(params.cell_type_ewings_ews_high_list),
      file(params.cell_type_ewings_ews_low_list)
    )

  emit:
    ewing_aucell.out // [sample_id, project_id, [list of aucell_output_files]]
}
