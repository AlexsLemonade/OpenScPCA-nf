#!/usr/bin/env nextflow

// Workflow to create gene order files for use with inferCNV

process create_gene_order_files {
  container Utils.pullthroughContainer(params.scpcatools_slim_container, params.pullthrough_registry)
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/infercnv-gene-order", mode: 'copy'
  input:
    path gtf_file
    path cytoband_file
  output:
    path "infercnv-gene-order_chr_*.txt", emit: chr_file, arity: '1'
    path "infercnv-gene-order_arms_*.txt", emit: arms_file, arity: '1'
  script:
    """
    prepare-gene-order-files.R \
      --gtf_file ${gtf_file} \
      --cytoband_file ${cytoband_file}
    """
  stub:
    """
    touch infercnv-gene-order_chr_stub.txt
    touch infercnv-gene-order_arms_stub.txt
    """
}


workflow infercnv_gene_order {
  main:
    create_gene_order_files(file(params.gtf_file), file(params.cytoband_file))

  emit:
    chr_file = create_gene_order_files.out.chr_file
    arms_file = create_gene_order_files.out.arms_file
}
