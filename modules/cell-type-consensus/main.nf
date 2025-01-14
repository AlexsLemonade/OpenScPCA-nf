#!/usr/bin/env nextflow

// Workflow to assign consensus cell type labels

// module parameters
params.panglao_ref_file = file('https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/b870a082bc9acd3536c5f8d2d52550d8fe8a4239/analyses/cell-type-consensus/references/panglao-cell-type-ontologies.tsv')
params.consensus_ref_file = file('https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/b870a082bc9acd3536c5f8d2d52550d8fe8a4239/analyses/cell-type-consensus/references/consensus-cell-type-reference.tsv')

process save_celltypes {
  container params.consensus_cell_type_container
  tag "${sample_id}"
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
  output:
    tuple val(project_id),
          path(output_files)
  script:
    output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "__original-cell-types.tsv")
      }
    """
    for file in ${library_files}; do
      save-coldata.R \
        --input_sce_file \$file \
        --output_file \$(basename \${file%.rds}__original-cell-types.tsv)
    done
    """

  stub:
    output_files = library_files
      .collect{
        it.name.replaceAll(/(?i).rds$/, "_original-cell-types.tsv")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_original-cell-types.tsv)
    done
    """
}

process assign_consensus {
  container params.consensus_cell_type_container
  tag "${project_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-consensus", mode: 'copy'
  input:
    tuple val(project_id),
          path(cell_type_files)
  output:
    path consensus_output_file
  script:
    input_files = cell_type_files.join(',')
    consensus_output_file = "${project_id}_consensus-cell-types.tsv.gz"
    """
    combine-celltype-tables.R \
      --input_tsv_files ${input_files} \
      --panglao_ref_file ${params.panglao_ref_file} \
      --consensus_ref_file ${consensus_ref_file} \
      --output_file ${consensus_output_file}
    """

  stub:
    input_files = cell_type_files.join(',')
    consensus_output_file = "${project_id}_consensus-cell-types.tsv.gz"
    """
    touch ${consensus_output_file}
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

    // save cell type information for each library
    save_celltypes(libraries_ch)

    cell_type_files_ch = save_celltypes.out
      .groupTuple(by: 0) // group by project id

    // assign consensus cell types by project
    assign_consensus(cell_type_files_ch)

  emit:
    assign_consensus.out // [project_id, consensus_output_file]
}
