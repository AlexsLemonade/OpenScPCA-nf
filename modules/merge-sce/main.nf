#!/usr/bin/env nextflow

// Workflow to merge SCE objects into a single object.
// This workflow does NOT perform integration, i.e. batch correction.

// module parameters
params.reuse_merge = false

// merge workflow variables
def publish_merge_base = "${params.results_bucket}/${params.release_prefix}/merge_sce"
def merge_report_template = "${projectDir}/modules/merge-sce/resources/merge-report.rmd"


// merge individual SCE objects into one SCE object
process merge_group {
  container "ghcr.io/alexslemonade/scpcatools-slim:edge"
  tag "${merge_group_id}"
  label 'mem_max'
  label 'long_running'
  publishDir "${publish_merge_base}/${merge_group_id}"
  input:
    tuple val(merge_group_id), val(library_ids), path(processed_files), val(has_adt)
  output:
    tuple val(merge_group_id), path(merged_sce_file), val(has_adt)
  script:
    input_library_ids = library_ids.join(',')
    input_sces = processed_files.join(',')
    merged_sce_file = "${merge_group_id}_merged.rds"
    """
    merge_sces.R \
      --input_library_ids '${input_library_ids}' \
      --input_sce_files '${input_sces}' \
      --output_sce_file '${merged_sce_file}' \
      --threads ${task.cpus}
    """

  stub:
    merged_sce_file = "${merge_group_id}_merged.rds"
    """
    touch ${merged_sce_file}
    """
}

// create merge report
process generate_merge_report {
  container "ghcr.io/alexslemonade/scpcatools-reports:edge"
  tag "${merge_group_id}"
  publishDir "${publish_merge_base}/${merge_group_id}"
  label 'mem_max'
  input:
    tuple val(merge_group_id), path(merged_sce_file), val(has_adt)
    path(report_template)
  output:
    path(merge_report)
  script:
    merge_report = "${merge_group_id}_merged-summary-report.html"
    """
    #!/usr/bin/env Rscript

    rmarkdown::render(
      '${report_template}',
      output_file = '${merge_report}',
      params = list(merge_group = '${merge_group_id}',
                    merged_sce_file = '${merged_sce_file}',
                    batch_column = 'library_id')
    )
    """
  stub:
    merge_report = "${merge_group_id}_merged-summary-report.html"
    """
    touch ${merge_report}
    """
}

process export_anndata {
    container "ghcr.io/alexslemonade/scpcatools-anndata:edge"
    label 'mem_max'
    label 'long_running'
    tag "${merge_group_id}"
    publishDir "${publish_merge_base}/${merge_group_id}"
    input:
      tuple val(merge_group_id), path(merged_sce_file), val(has_adt)
    output:
      tuple val(merge_group_id), path("${merge_group_id}_merged_*.h5ad")
    script:
      rna_h5ad_file = "${merge_group_id}_merged_rna.h5ad"
      feature_h5ad_file = "${merge_group_id}_merged_adt.h5ad"
      """
      sce_to_anndata.R \
        --input_sce_file ${merged_sce_file} \
        --output_rna_h5 ${rna_h5ad_file} \
        --output_feature_h5 ${feature_h5ad_file} \
        --is_merged \
        ${has_adt ? "--feature_name adt" : ''}

      # move normalized counts to X in AnnData
      move_counts_anndata.py --anndata_file ${rna_h5ad_file}
      ${has_adt ? "move_counts_anndata.py --anndata_file ${feature_h5ad_file}" : ''}
      """
    stub:
      rna_h5ad_file = "${merge_group_id}_merged_rna.h5ad"
      feature_h5ad_file = "${merge_group_id}_merged_adt.h5ad"
      """
      touch ${rna_h5ad_file}
      ${has_adt ? "touch ${feature_h5ad_file}" : ''}
      """
}

workflow merge_sce {
  take:
    project_ch  // Channel of [project_id, file(project_dir)]
  main:

    project_branch = project_ch
      .branch{
        // multiplexed libraries are subdirectories with more than one sample id
        multiplexed: files(it[1] / "*", type: "dir").any{it.name =~ /SCPCS\d+_SCPCS\d+/}
        single_sample: true
      }

    // get all SCE files by project
    // this will be a channel of [project_id, [library_ids], [processed_sce_files], has_adt]
    libraries_ch = project_branch.single_sample
      .map{project_id, project_dir -> {
        def processed_files = files(project_dir / "**_processed.rds")
        def library_ids = processed_files.collect{it.name.replace('_processed.rds', '')}
        def has_adt = files(project_dir / "**_processed_adt.h5ad").size > 0 // true if there are any adt files
        return [project_id, library_ids, processed_files, has_adt]
      }}

    project_branch.multiplexed
      .subscribe{
        log.warn("Not merging ${it[0]} because it contains multiplexed libraries.")
      }

    libraries_branch = libraries_ch
      .branch{
        has_merge: file("${publish_merge_base}/${it[0]}/${it[0]}_merged.rds").exists() && params.reuse_merge
        make_merge: true
      }

    pre_merged_ch = libraries_branch.has_merge
      .map{[ // [project id, merged_file, has_adt] to match the output of merge_sce
        it[0],
        file("${publish_merge_base}/${it[0]}/${it[0]}_merged.rds"),
        it[3]
      ]}

    // merge SCE objects
    merge_group(libraries_branch.make_merge)

    merged_ch = merge_group.out.mix(pre_merged_ch)

    // generate merge report
    generate_merge_report(merged_ch, file(merge_report_template))

    // export merged objects to AnnData
    export_anndata(merged_ch)
}
