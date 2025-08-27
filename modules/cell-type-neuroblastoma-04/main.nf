#!/usr/bin/env nextflow

// Workflow to assign neuroblastoma (SCPCP000004) cell type labels


process convert_nbatlas {
  container params.cell_type_nb_04_container
  label 'mem_8'
  input:
    path nbatlas_seurat_file
  output:
    path nbatlas_sce_file, emit: sce
    tuple path(nbatlas_anndata_file),
          path(nbatlas_hvg_file), emit: anndata
  script:
    nbatlas_sce_file = "nbatlas_sce.rds"
    nbatlas_anndata_file = "nbatlas_anndata.h5ad"
    nbatlas_hvg_file = "nbatlas_hvg.txt.gz"
    """
    convert-nbatlas.R \
      --nbatlas_file ${nbatlas_seurat_file} \
      --sce_file ${nbatlas_sce_file} \
      --anndata_file ${nbatlas_anndata_file} \
      --nbatlas_hvg_file ${nbatlas_hvg_file}
    """
  stub:
    nbatlas_sce_file = "nbatlas_sce.rds"
    nbatlas_anndata_file = "nbatlas_anndata.h5ad"
    nbatlas_hvg_file = "nbatlas_hvg.txt.gz"
    """
    touch ${nbatlas_sce_file}
    touch ${nbatlas_anndata_file}
    touch ${nbatlas_hvg_file}
    """
}


process train_singler_model {
  container params.cell_type_nb_04_container
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-neuroblastoma-04"
  input:
    path nbatlas_sce_file
    path gtf_file
  output:
    path nbatlas_singler_model
  script:
    nbatlas_singler_model = "nbatlas_singler_model.rds"
    """
    train-singler-model.R \
      --nbatlas_file ${nbatlas_sce_file} \
      --gtf_file ${gtf_file} \
      --singler_model_file ${nbatlas_singler_model}
    """
  stub:
    nbatlas_singler_model = "nbatlas_singler_model.rds"
    """
    touch ${nbatlas_singler_model}
    """
}



workflow cell_type_neuroblastoma_04 {
  take:
    sample_ch  // [sample_id, project_id, sample_path]
  main:
    // create [sample_id, project_id, [list of processed files]]
    libraries_ch = sample_ch
      .map{sample_id, project_id, sample_path ->
        def library_files = Utils.getLibraryFiles(sample_path, format: "sce", process_level: "processed")
        return [sample_id, project_id, library_files]
      }

    // convert NBAtlas to SCE and AnnData objects
    convert_nbatlas(file(params.cell_type_nb_04_nbatlas_url))

    // train Singler model
    train_singler_model(convert_nbatlas.out.sce, file(params.gtf_file))

    // Emit temporarily for testing while workflow is being developed
    emit:
      train_singler_model.out
}
