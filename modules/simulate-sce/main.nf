process permute_metadata {
  container 'ghcr.io/alexslemonade/scpca-tools:v0.3.2'
  tag "$project_id"
  input:
    tuple val(project_id), path(metadata_file)
  output:
    tuple val(project_id), path("${project_id}/${metadata_file.name}")
  script:
    """
    mkdir ${project_id}
    permute_metadata.R \
      --metadata_file ${metadata_file} \
      --output_file ${project_id}/${metadata_file.name}
    """
  stub:
    """
    mkdir ${project_id}
    touch ${project_id}/${metadata_file.name}
    """
}

process simulate_sample {
  container 'ghcr.io/alexslemonade/scpca-tools:v0.3.2'
  tag "$project_id-$sample_id"
  input:
    tuple val(project_id), val(sample_id), path(rds_files), path(metadata_file)
  output:
    tuple val(project_id), val(sample_id), path(sample_id)
  script:
    """
    mkdir input
    mv ${rds_files} input/
    mkdir ${sample_id}
    simulate-sce.R \
      --sample_dir input \
      --metadata_file ${metadata_file} \
      --output_dir ${sample_id}
    """
  stub:
    """
    mkdir ${sample_id}
    for f in ${rds_files}; do
      touch ${sample_id}/\$(basename \$f)
    done
    """
}

workflow simulate_sce {
  take:
    project_ch  // Channel of project names and project directories
  main:
    // metadata file for each project
    metadata_ch = project_ch.map{[it[0], it[1] / 'single_cell_metadata.tsv']}
    permuted_metadata_ch = permute_metadata(metadata_ch)
    // list rds files for each project and sample
    sample_ch = project_ch.map{[it[0], it[1].listFiles().findAll{it.isDirectory()}]}
      .transpose() // transpose to get a channel of project ids and sample directories
      .map{[it[0], it[1].name, it[1].listFiles().findAll{it.name.endsWith(".rds")}]}
      .combine(permuted_metadata_ch, by: 0) // combine with permuted metadata
    // simulate samples for each project
    simulate_sample(sample_ch)


    bulk_ch = project_ch.map{[it[0], it[1] / 'bulk_quant.tsv']}

}
