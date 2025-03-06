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
    path marker_gene_file
  output:
    tuple val(sample_id),
          val(project_id),
          path(aucell_output_files),
          path(mean_exp_output_files)
  script:
    aucell_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_ewing-aucell-results.tsv")
      }
    mean_exp_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_ewing-geneset-means.tsv")
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
        --output_file \$(basename \${file%.rds}_ewing-aucell-results.tsv) \
        --threads ${task.cpus} \
        --seed 2025

      mean-gene-set-expression.R \
        --sce_file ${library_files} \
        --cell_state_markers_file ${marker_gene_file} \
        --output_file \$(basename \${file%.rds}_ewing-geneset-means.tsv)

    done
    """

  stub:
    aucell_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_ewing-aucell-results.tsv")
      }
    mean_exp_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_ewing-geneset-means.tsv")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_ewing-aucell-results.tsv)
      touch \$(basename \${file%.rds}_ewing-geneset-means.tsv)
    done
    """
}

process ewing_assign_celltypes {
  container params.cell_type_ewing_container
  tag "${project_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-ewings/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(aucell_files),
          path(mean_exp_files),
          path(consensus_celltype_files)
    path auc_thresholds_file
  output:
    tuple val(sample_id),
          val(project_id),
          path(celltype_assignment_output_files)
  script:
    celltype_assignment_output_files = aucell_files
      .collect{
        it.name.replaceAll(/(?i)_ewing-aucell-results.tsv$/, "_ewing-celltype-assignments.tsv")
      }
    """
    for file in ${aucell_files}; do
      library_id=\$(basename \${file%_ewing-aucell-results.tsv})

      # find files that have the appropriate library id in file name
      consensus_celltype_file=\$(ls ${consensus_celltype_files} | grep "\$(library_id)")
      mean_exp_file=\$(ls ${mean_exp_files} | grep "\${library_id}")

      assign-celltypes.R \
        --consensus_celltype_file \${consensus_celltype_file} \
        --aucell_results_file \${file} \
        --auc_thresholds_file ${auc_thresholds_file} \
        --mean_gene_expression_file \${mean_exp_file} \
        --output_file \$(basename \${file%_ewing-aucell-results.tsv}_ewing-celltype-assignments.tsv)
    done
    """

  stub:
    celltype_assignment_output_files = aucell_files
      .collect{
        it.name.replaceAll(/(?i)_ewing-aucell-results.tsv$/, "_ewing-celltype-assignments.tsv")
      }
    """
    for file in ${aucell_files}; do
      touch \$(basename \${file%_ewing-aucell-results.tsv}_ewing-celltype-assignments.tsv)
    done
    """
}



workflow cell_type_ewings {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
    consensus_ch // [sample_id, project_id, [list of consensus_output_files], [list of gene_exp_output_files]]
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
      file(params.cell_type_ewings_ews_low_list),
      file(params.cell_type_ewings_marker_gene_file)
    )

    // combine aucell and gene set output with consensus cell types
    assign_ch = ewing_aucell.out
      // join by sample ID and project ID
      .join(consensus_ch, by: [0, 1]) // sample id, project id, aucell, mean exp, consensus, consensus gene exp
      .take(4) // we don't need the consensus gene exp file

    // assign cell types
    ewing_assign_celltypes(assign_ch, file(params.cell_type_ewings_auc_thresholds_file))

  emit:
    aucell = ewing_aucell.out // [sample_id, project_id, aucell_output_file, mean gene expression output file]
    celltypes = ewing_assign_celltypes. out // [sample_id, project_id, cell type assignment output file]
}
