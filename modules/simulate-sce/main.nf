#!/usr/bin/env nextflow

// Workflow to create simulated/permuted metadata, bulk, and SCE objects
// for testing OpenSCPCA workflows


// module parameters
params.simulate_sce_container = 'public.ecr.aws/openscpca/simulate-sce:v0.1.0'

process permute_metadata {
  container params.simulate_sce_container
  tag "$project_id"
  publishDir "${params.sim_bucket}/test/${project_id}", mode: 'copy'
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

process simulate_samples {
  container params.simulate_sce_container
  label "mem_8"
  tag "$project_id-$sample_id"
  publishDir "${params.sim_bucket}/test/${project_id}", mode: 'copy'
  input:
    tuple val(project_ids),
          val(sample_ids),
          path(rds_files, stageAs: 'input/*'),
          val(metadata_filenames),
          path(metadata_files)
  output:
    tuple val(project_ids), val(sample_ids), path(sample_ids)
  script:
    """
    mkdir -p ${sample_ids}
    samples=(${sample_ids})
    metadata=(${metadata_filenames})
    n=${sample_ids.size()}
    for i in \$(seq 1 \$n); do
      simulate-sce.R \
        --sample_dir input \
        --metadata_file \${metadata[\$i]} \
        --output_dir \${samples[\$i]}

      sce-to-anndata.R --dir \${samples[\$i]}
      move-anndata-counts.R --dir \${samples[\$i]}
    done
    """
  stub:
    """
    mkdir -p ${sample_ids}
    samples=(${sample_ids})
    for i in \$(seq 1 $n); do
      for file in ${rds_files}; do
        touch "\${samples[\$i]}/\$(basename \$file)"
        touch "\${samples[\$i]}/\$(basename \${file%.rds}.h5ad)"
      done
    done
    """
}

process permute_bulk{
  container params.simulate_sce_container
  tag "$project_id"
  publishDir "${params.sim_bucket}/test/${project_id}", mode: 'copy'
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
    project_ch  // Channel of [project_id, file(project_dir)]
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

    // create groups of 10 for for more efficient processing
    grouped_samples = sample_ch.collate(10).map{it.transpose()}
    // now [[project_id1, project_id2, ...], [sample_id1, sample_id2, ...], [rds_files1, rds_files2, ...], [metadata1, metadata2, ...]]
    // we can't pass the same file path multiple times, so lets reduce those for another arg
    .map{ project_ids, sample_ids, rds_files, metadata_files ->
      def unique_metadata = metadata_files.unique(false) // false to not modify original
      return [project_ids, sample_ids, rds_files, metadata_files, unique_metadata]
    }

    // simulate samples for each group of samples
    simulate_samples(grouped_samples)

}
