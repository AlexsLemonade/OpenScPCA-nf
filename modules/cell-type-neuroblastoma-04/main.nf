#!/usr/bin/env nextflow

// Workflow to assign neuroblastoma (SCPCP000004) cell type labels


process nb_04_convert_nbatlas {
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


process nb_04_train_singler_model {
  container params.cell_type_nb_04_container
  label 'mem_max'
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


process nb_04_train_scanvi_model {
  container params.cell_type_nb_04_container
  label 'mem_16'
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

process nb_04_classify_singler {
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
        --sce_file \$file \
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



process nb_04_classify_scanvi {
  container params.cell_type_nb_04_container
  tag "${sample_id}"
  label 'mem_8'
  input:
    tuple val(sample_id),
          val(project_id),
          path(library_files)
    path hvg_file
    path scanvi_ref_model_dir
  output:
    tuple val(sample_id),
          val(project_id),
          path("*_scanvi.tsv.gz")
  script:
    """
    for file in ${library_files}; do

      anndata_file="prepared.h5ad"
      scanvi_tsv=\$(basename \${file%.rds}_scanvi.tsv.gz)

      # Prepare the query data for input to scANVI/scArches
      prepare-scanvi-query.R \
        --sce_file \$file \
        --nbatlas_hvg_file ${hvg_file} \
        --prepared_anndata_file \${anndata_file}

      # Run label transfer with scANVI/scArches
      classify-scanvi.py \
        --query_file \${anndata_file} \
        --reference_scanvi_model_dir ${scanvi_ref_model_dir} \
        --predictions_tsv \${scanvi_tsv}
    done
    """
  stub:
    """
    for file in ${library_files}; do
      touch \$(basename \${file%.rds}_scanvi.tsv.gz)
    done
    """
}


process nb_04_assign_celltypes {
  container params.cell_type_nb_04_container
  tag "${sample_id}"
  label 'mem_8'
  publishDir "${params.results_bucket}/${params.release_prefix}/cell-type-neuroblastoma/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(singler_files),
          path(scanvi_files),
          path(consensus_files)
    path(nbatlas_label_file)
    path(nbatlas_ontology_file)
    path(consensus_validation_file)
    val(scanvi_pp_threshold)
  output:
    tuple val(sample_id),
          val(project_id),
          path(celltype_assignment_output_files)
  script:
    library_ids = singler_files.collect{(it.name =~ /SCPCL\d{6}/)[0]}
    celltype_assignment_output_files = library_ids.collect{"${it}_neuroblastoma-04_celltype-assignments.tsv.gz"}
    """
    for library_id in ${library_ids.join(" ")}; do
      # find files that have the appropriate library id in file name
      singler_file=\$(ls ${singler_files} | grep "\${library_id}")
      scanvi_file=\$(ls ${scanvi_files} | grep "\${library_id}")
      consensus_file=\$(ls ${consensus_files} | grep "\${library_id}")

      # output file
      output_tsv=\${library_id}_neuroblastoma-04_celltype-assignments.tsv.gz
      assign-labels.R \
        --singler_tsv \${singler_file} \
        --scanvi_tsv \${scanvi_file} \
        --consensus_tsv \${consensus_file} \
        --nbatlas_label_tsv ${nbatlas_label_file} \
        --nbatlas_ontology_tsv ${nbatlas_ontology_file} \
        --consensus_validation_tsv ${consensus_validation_file} \
        --scanvi_posterior_threshold ${scanvi_pp_threshold} \
        --annotations_tsv \${output_tsv}
    done
    """

  stub:
    library_ids = singler_files.collect{(it.name =~ /SCPCL\d{6}/)[0]}
    celltype_assignment_output_files = library_ids.collect{"${it}_neuroblastoma-04_celltype-assignments.tsv.gz"}
    """
    for library_id in ${library_ids.join(" ")}; do
      output_tsv=\${library_id}_neuroblastoma-04_celltype-assignments.tsv.gz
      touch \${output_tsv}
    done
    """
}


workflow cell_type_neuroblastoma_04 {
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

    /////////////////////////////////////////////////////
    // Prepare references for cell type classification //
    /////////////////////////////////////////////////////

    // convert NBAtlas to SCE and AnnData objects
    // emits: sce, anndata, hvg_file
    nb_04_convert_nbatlas(file(params.cell_type_nb_04_nbatlas_url))

    // train SingleR model
    // outputs the singler model file
    nb_04_train_singler_model(nb_04_convert_nbatlas.out.sce, file(params.gtf_file))

    // train scANVI model
    // outputs the scanvi model directory
    nb_04_train_scanvi_model(nb_04_convert_nbatlas.out.anndata)

    /////////////////////////////////////////////////////
    //        Perform  cell type classification        //
    /////////////////////////////////////////////////////

    // classify with SingleR
    nb_04_classify_singler(
      libraries_ch,
      nb_04_train_singler_model.out
    )

    // classify with scANVI
    nb_04_classify_scanvi(
      libraries_ch,
      nb_04_convert_nbatlas.out.hvg_file,
      nb_04_train_scanvi_model.out
    )

    // combine singler, scanvi, and consensus cell types for assignment
    assign_ch = nb_04_classify_singler.out
      // join scanvi by sample ID and project ID
      .join(nb_04_classify_scanvi.out, by: [0, 1]) // sample id, project id, singler, scanvi
      // join consensus by sample ID and project ID
      .join(consensus_ch, by: [0, 1]) // sample id, project id, singler, scanvi, consensus, consensus gene exp
      .map { it.dropRight(1) } // we don't need the consensus gene exp file

    // assign final labels
    nb_04_assign_celltypes(
      assign_ch,
      params.cell_type_nb_04_label_map_file,
      params.cell_type_nb_04_ontology_map_file,
      params.cell_type_nb_04_validation_group_file,
      params.cell_type_nb_04_scanvi_pp_threshold
    )

    // add metadata to output tuple
    nb_04_output_ch = nb_04_assign_celltypes.out
      .map{ sample_id, project_id, assignment_files -> tuple(
        sample_id,
        project_id,
        assignment_files,
        [ // annotation metadata
          module_name: "cell-type-neuroblastoma-04",
          annotation_column: "neuroblastoma_04_annotation",
          ontology_column: "neuroblastoma_04_ontology"
        ]
      )}

  emit:
    celltypes = nb_04_output_ch // [sample_id, project_id, [cell type assignment files], annotation_metadata]
}
