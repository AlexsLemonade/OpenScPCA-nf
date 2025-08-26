#!/usr/bin/env nextflow

// Workflow to assign cell types using SCimilarity

process assign_scimilarity {
  container params.cell_type_scimilarity_container
  tag "${sample_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-scimilarity/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
    path scimilarity_model
    path ontology_map_file
  output:
    tuple val(sample_id),
          val(project_id),
          path(scimilarity_annotation_files)
  script:
    scimilarity_annotation_files = library_files
      .collect{
        it.name.replaceAll(/(?i)_rna.h5ad$/, "_scimilarity-celltype-assignments.tsv.gz")
      }
    """
    for file in ${library_files}; do
      run-scimilarity.py \
        --model_dir ${scimilarity_model} \
        --processed_h5ad_file \$file \
        --ontology_map_file ${ontology_map_file} \
        --predictions_tsv \$(basename \${file%_rna.h5ad}_scimilarity-celltype-assignments.tsv.gz) \
        --seed 2025
    done
    """

  stub:
    scimilarity_annotation_files = library_files
      .collect{
        it.name.replaceAll(/(?i)_rna.h5ad$/, "_scimilarity-celltype-assignments.tsv.gz")
      }
    """
    for file in ${library_files}; do
      touch \$(basename \${file%_rna.h5ad}_scimilarity-celltype-assignments.tsv.gz)
    done
    """
}



workflow cell_type_scimilarity {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:
    // create [sample_id, project_id, [list of processed files]]
    libraries_ch = sample_ch
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "anndata", process_level: "processed")
        // filter to only include _rna.h5ad files and remove any _adt.h5ad files
        library_files = library_files.findAll{ it.name =~ /(?i)_rna.h5ad$/ }
        return [sample_id, project_id, library_files]
      }

    // assign cell types using scimilarity
    assign_scimilarity(
      libraries_ch,
      file(params.cell_type_scimilarity_model, type: 'dir'),
      file(params.cell_type_scimilarity_ontology_ref_file)
    )

  emit:
    assign_scimilarity.out // [sample_id, project_id, [list of scimilarity output files]]
}
