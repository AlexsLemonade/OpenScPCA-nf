params.sim_pubdir = 's3://openscpca-temp-simdata/test'

process permute_metadata {
  container 'ghcr.io/alexslemonade/scpca-tools:v0.3.2'
  tag "$project_id"
  publishDir "${params.sim_pubdir}/${project_id}", mode: 'copy'
  input:
    tuple val(project_id),
          path(metadata_file, stageAs: 'input/*')
  output:
    tuple val(project_id), path("${metadata_file.fileName.name}")
  script:
    """
    permute-metadata.R \
      --metadata_file ${metadata_file} \
      --output_file ${metadata_file.fileName.name}
    """
  stub:
    """
    touch ${metadata_file.fileName.name}
    """
}

process simulate_sample {
  container 'ghcr.io/alexslemonade/scpca-tools:v0.3.2'
  tag "$project_id-$sample_id"
  publishDir "${params.sim_pubdir}/${project_id}", mode: 'copy'
  input:
    tuple val(project_id),
          val(sample_id),
          path(rds_files, stageAs: 'input/*'),
          path(metadata_file)
  output:
    tuple val(project_id), val(sample_id), path(sample_id)
  script:
    """
    mkdir ${sample_id}
    simulate-sce.R \
      --sample_dir input \
      --metadata_file ${metadata_file} \
      --output_dir ${sample_id}

    sce-to-anndata.R --dir ${sample_id}
    """
  stub:
    """
    mkdir ${sample_id}
    for f in ${rds_files}; do
      touch ${sample_id}/\$(basename \$f)
      touch ${sample_id}/\$(basename \${f%.rds}.hdf5)
    done
    """
}

process permute_bulk{
  container 'ghcr.io/alexslemonade/scpca-tools:v0.3.2'
  tag "$project_id"
  publishDir "${params.sim_pubdir}/${project_id}", mode: 'copy'
  input:
    tuple val(project_id),
          path(bulk_quant, stageAs: 'input/*'),
          path(bulk_metadata)
  output:
    tuple val(project_id),
          path("${bulk_quant.fileName.name}"),
          path("${bulk_metadata}")
  script:
    """
    permute-bulk.R \
      --bulk_file ${bulk_quant} \
      --output_dir .
    """
  stub:
    """
    touch ${bulk_quant.fileName.name}
    """
}

workflow simulate_sce {
  take:
    project_ch  // Channel of project names and project directories
  main:
    // metadata file for each project
    metadata_ch = project_ch.map{[it[0], it[1] / 'single_cell_metadata.tsv']}
    permuted_metadata_ch = permute_metadata(metadata_ch)

    // get bulk files for each project, if present
    bulk_ch = project_ch.map{[it[0], it[1] / 'bulk_quant.tsv', it[1] / 'bulk_metadata.tsv']}
      .filter{it[1].exists()}
    permute_bulk(bulk_ch)

    // list rds files for each project and sample
    sample_ch = project_ch.map{[it[0], it[1].listFiles().findAll{it.isDirectory()}]}
      .transpose() // transpose to get a channel of project ids and sample directories
      // get rds file list for each sample
      .map{[it[0], it[1].name, it[1].listFiles().findAll{it.name.endsWith(".rds")}]}
      .combine(permuted_metadata_ch, by: 0) // combine with permuted metadata
    // simulate samples for each project
    simulate_sample(sample_ch)



}
