params.sim_pubdir = 's3://openscpca-temp-simdata/test'
params.simulate_sce_container = 'ccdl/openscpca-simulate-sce:latest'

process permute_metadata {
  container params.simulate_sce_container
  tag "$project_id"
  publishDir "${params.sim_pubdir}/${project_id}", mode: 'copy'
  input:
    tuple val(project_id),
          path(metadata_file, stageAs: 'input/*')
  output:
    tuple val(project_id), path(permuted_file)
  script:
    permuted_file = metadata_file.fileName.name
    """
    permute-metadata.R \
      --metadata_file ${metadata_file} \
      --output_file ${permuted_file}
    """
  stub:
    permuted_file = metadata_file.fileName.name
    """
    touch ${permuted_file}
    """
}

process simulate_sample {
  container params.simulate_sce_container
  label "mem_8"
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
      touch ${sample_id}/\$(basename \${f%.rds}.h5ad)
    done
    """
}

process permute_bulk{
  container params.simulate_sce_container
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
    // metadata file for each project: [project_id, metadata_file]
    metadata_ch = project_ch.map{[it[0], it[1] / 'single_cell_metadata.tsv']}
    permuted_metadata_ch = permute_metadata(metadata_ch)

    // get bulk files for each project, if present: [project_id, bulk_quant_file, bulk_metadata_file]
    bulk_ch = project_ch.map{[it[0], it[1] / 'bulk_quant.tsv', it[1] / 'bulk_metadata.tsv']}
      .filter{it[1].exists()}
    permute_bulk(bulk_ch)

    // list rds files for each project and sample: [project_id, [sample_dir1, sample_dir2, ...]]
    sample_ch = project_ch.map{[it[0], it[1].listFiles().findAll{it.isDirectory()}]}
      .transpose() // transpose to get a channel of [project_id, sample_dir]
      // get rds file list for each sample: [project_id, sample_id, [rds_file1, rds_file2, ...]]
      .map{[it[0], it[1].name, it[1].listFiles().findAll{it.name.endsWith(".rds")}]}
      .combine(permuted_metadata_ch, by: 0) // combine with permuted metadata
      // final output: [project_id, sample_id, [rds_file1, rds_file2, ...], permuted_metadata_file]

    // simulate samples for each project
    simulate_sample(sample_ch)

}
