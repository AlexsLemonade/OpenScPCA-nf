#!/usr/bin/env nextflow

// Workflow to assign neuroblastoma (SCPCP000004) cell type labels


process convert_nbatlas {
  container params.cell_type_nb_04_container
  label 'mem_32'
  input:
    path nbatlas_seurat_file
  output:
    path nbatlas_sce_file, emit: sce
    path nbatlas_anndata_file, emit: anndata
    path nbatlas_hvg_file, emit: hvg_file
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
  label 'mem_32'
  label 'cpus_4'
  input:
    path nbatlas_sce_file
    path gtf_file
  output:
    path nbatlas_singler_model
  script:
    nbatlas_singler_model = "nbatlas_singler_model.rds"
    """
    train-singler-model.R \
      --nbatlas_sce ${nbatlas_sce_file} \
      --gtf_file ${gtf_file} \
      --singler_model_file ${nbatlas_singler_model} \
      --threads ${task.cpus}
    """
  stub:
    nbatlas_singler_model = "nbatlas_singler_model.rds"
    """
    touch ${nbatlas_singler_model}
    """
}


process train_scanvi_model {
  container params.cell_type_nb_04_container
  label 'mem_8'
  input:
    path nbatlas_anndata_file
  output:
    path scanvi_ref_model_dir
  script:
    scanvi_ref_model_dir = "scanvi_ref_model_dir"
    """
    train-scanvi-model.py \
      --reference_file ${nbatlas_anndata_file} \
      --reference_scanvi_model_dir ${scanvi_ref_model_dir}
    """
  stub:
    scanvi_ref_model_dir = "scanvi_ref_model_dir"
    """
    mkdir ${scanvi_ref_model_dir}
    # touch expected model files
    touch ${scanvi_ref_model_dir}/adata.h5ad
    touch ${scanvi_ref_model_dir}/model.pt
    """
}

process classify_singler {
  container params.cell_type_nb_04_container
  tag "${sample_id}"
  label 'mem_8'
  label 'cpus_2'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
    path singler_model
  output:
    tuple val(sample_id),
          val(project_id),
          path("*_singler.tsv.gz")
  script:
    """
    for file in ${library_files}; do
      classify-singler.R \
        --sce_file ${file} \
        --singler_model_file ${singler_model} \
        --singler_output_tsv \$(basename \${file%.rds}_singler.tsv.gz) \
        --threads ${task.cpus}
    done
    """
  stub:
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_singler.tsv.gz)
    done
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

    /////////////////////////////////////////////////////
    // Prepare references for cell type classification //
    /////////////////////////////////////////////////////

    // convert NBAtlas to SCE and AnnData objects
    // emits: sce, anndata, hvg_file
    convert_nbatlas(file(params.cell_type_nb_04_nbatlas_url))

    // train SingleR model
    // outputs the singler model file
    train_singler_model(convert_nbatlas.out.sce, file(params.gtf_file))

    // train scANVI model
    // outputs the scanvi model directory
    train_scanvi_model(convert_nbatlas.out.anndata)

    /////////////////////////////////////////////////////
    //        Perform  cell type classification        //
    /////////////////////////////////////////////////////

    // classify with SingleR
    classify_singler(
      libraries_ch,
      train_singler_model.out
    )

}
