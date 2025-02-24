#!/usr/bin/env nextflow

// Workflow to assign consensus cell type labels

process assign_consensus {
  container params.consensus_cell_type_container
  tag "${project_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-consensus/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
    path blueprint_ref
    path panglao_ref
    path consensus_ref
    path marker_gene_ref
  output:
    tuple val(sample_id),
          val(project_id),
          path(consensus_output_files),
          path(gene_exp_output_files)
  script:
    consensus_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_consensus-cell-types.tsv.gz")
      }
    gene_exp_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_marker-gene-expression.tsv.gz")
      }
    """
    for file in ${library_files}; do
      assign-consensus-celltypes.R \
        --sce_file \$file \
        --blueprint_ref_file ${blueprint_ref} \
        --panglao_ref_file ${panglao_ref} \
        --consensus_ref_file ${consensus_ref} \
        --marker_gene_file ${marker_gene_ref} \
        --consensus_output_file \$(basename \${file%.rds}_consensus-cell-types.tsv.gz) \
        --gene_exp_output_file \$(basename \${file%.rds}_marker-gene-expression.tsv.gz)
    done
    """

  stub:
    consensus_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_consensus-cell-types.tsv.gz")
      }
    gene_exp_output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_marker-gene-expression.tsv.gz")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_consensus-cell-types.tsv.gz)
      touch \$(basename \${file%.rds}_marker-gene-expression.tsv.gz)
    done
    """
}



workflow cell_type_consensus {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:
    // create [sample_id, project_id, [list of processed files]]
    libraries_ch = sample_ch
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        return [sample_id, project_id, library_files]
      }

    // assign consensus cell types
    assign_consensus(
      libraries_ch,
      file(params.cell_type_blueprint_ref_file),
      file(params.cell_type_panglao_ref_file),
      file(params.cell_type_consensus_ref_file),
      file(params.cell_type_consensus_marker_gene_ref_file)
    )

  emit:
    assign_consensus.out // [sample_id, project_id, [list of consensus_output_files], [list of gene_exp_output_files]]
}
