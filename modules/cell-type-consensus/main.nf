#!/usr/bin/env nextflow

// Workflow to assign consensus cell type labels

process assign_consensus {
  container params.consensus_cell_type_container
  tag "${sample_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-consensus/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files),
          path(scimilarity_files)
    path blueprint_ref
    path panglao_ref
    path consensus_ref
    path val_marker_gene_ref
    path consensus_marker_gene_ref
  output:
    tuple val(sample_id),
          val(project_id),
          path(consensus_output_files),
          path(gene_exp_output_files)
  script:
    library_ids = library_files.collect{(it.name =~ /SCPCL\d{6}/)[0]}
    consensus_output_files = library_ids.collect{"${it}_processed_consensus-cell-types.tsv.gz"}
    gene_exp_output_files = library_ids.collect{"${it}_processed_marker-gene-expression.tsv.gz"}
    """
    for library_id in ${library_ids.join(" ")}; do
      # find files that have the appropriate library id in file name
      sce_file=\$(ls ${library_files} | grep "\${library_id}")

      # define scimilarity file as long as it's not empty
      if [[ -n "${scimilarity_files}" ]]; then
        scimilarity_file=\$(ls ${scimilarity_files} | grep "\${library_id}")
      else
        scimilarity_file=""
      fi

      assign-consensus-celltypes.R \
        --sce_file \$sce_file \
        --scimilarity_annotations_file "\$scimilarity_file" \
        --blueprint_ref_file ${blueprint_ref} \
        --panglao_ref_file ${panglao_ref} \
        --consensus_ref_file ${consensus_ref} \
        --validation_marker_gene_file ${val_marker_gene_ref} \
        --consensus_marker_gene_file ${consensus_marker_gene_ref} \
        --consensus_output_file \${library_id}_consensus-cell-types.tsv.gz \
        --gene_exp_output_file \${library_id}_marker-gene-expression.tsv.gz
    done
    """

  stub:
    library_ids = library_files.collect{(it.name =~ /SCPCL\d{6}/)[0]}
    consensus_output_files = library_ids.collect{"${it}_processed_consensus-cell-types.tsv.gz"}
    gene_exp_output_files = library_ids.collect{"${it}_processed_marker-gene-expression.tsv.gz"}
    """
    for library_id in ${library_ids.join(" ")}; do
      touch \${library_id}_processed_consensus-cell-types.tsv.gz
      touch \${library_id}_processed_marker-gene-expression.tsv.gz
    done
    """
}



workflow cell_type_consensus {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
    scimilarity_ch // [sample id, project id, [list of scimilarity files]]
  main:
    // create [sample_id, project_id, [list of processed files]]
    libraries_ch = sample_ch
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        return [sample_id, project_id, library_files]
      }

    // add scimilarity to input channel
    consensus_ch = libraries_ch
      // join by sample and project id
      // keep any instances of the library channel that are missing a scimilarity file
      .join(scimilarity_ch, by: [0,1], remainder: true) // [sample id, project id, [list of processed files], [list of scimilarity files]]
      .map{sample_id, project_id, sce_files, scimilarity_files -> tuple(
        sample_id,
        project_id,
        sce_files,
        scimilarity_files ?: []
      )}

    // assign consensus cell types
    assign_consensus(
      consensus_ch,
      file(params.cell_type_blueprint_ref_file),
      file(params.cell_type_panglao_ref_file),
      file(params.cell_type_consensus_ref_file),
      file(params.cell_type_consensus_validation_marker_genes_file),
      file(params.cell_type_consensus_all_marker_genes_file)
    )

  emit:
    assign_consensus.out // [sample_id, project_id, [list of consensus_output_files], [list of gene_exp_output_files]]
}
