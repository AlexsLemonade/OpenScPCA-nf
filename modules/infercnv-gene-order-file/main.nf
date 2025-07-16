#!/usr/bin/env nextflow

// Workflow to create gene order files for use with inferCNV

process create_gene_order_files {
  container params.scpcatools_slim_container
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/infercnv-gene-order-file", mode: 'copy'
  input:
    tuple path(gtf_file),
          path(cytoband_file)
  output:
    tuple path(gene_order_file),
          path(arms_gene_order_file)
  script:
    gene_order_file="${params.infercnv_gene_order_file_output_no_arms}"
    arms_gene_order_file="${params.infercnv_gene_order_file_output_with_arms}"
    """
      prepare-gene-order-files.R \
        --gtf_file ${gtf_file} \
        --cytoband_file ${cytoband_file} \
        --gene_order_file_name ${gene_order_file} \
        --arms_gene_order_file_name ${arms_gene_order_file}
    """
  stub:
    """
    touch ${params.infercnv_gene_order_file_output_no_arms}
    touch ${params.infercnv_gene_order_file_output_with_arms}
    """
}


workflow infercnv_gene_order_file {
  main:
     // Create input channel with URIs to GTF and cytoband files
    input_ch = Channel.of([
        file(params.infercnv_gene_order_file_gtf, checkIfExists: false),
        file(params.infercnv_gene_order_file_cytoband, checkIfExists: false)
    ])

    // Generate the gene order files
    create_gene_order_files(input_ch)

  emit:
    gene_order_files = create_gene_order_files.out // [gene_order_file, arm_gene_order_file]
}
