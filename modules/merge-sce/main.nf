#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Workflow to merge SCE objects into a single object.
// This workflow does NOT perform integration, i.e. batch correction.

// module parameters
params.reuse_merge = false


// workflow variables
def module_dir = "${projectDir}/modules/merge-sce"
def publish_merge_base = "${params.results_bucket}/${params.release_version}/merge_sce"
def merge_report_template = "${module_dir}/resources/merge-report.rmd"

// merge individual SCE objects into one SCE object
process merge_sce {
  container ghcr.io/alexslemonade/scpcatools-slim:edge
  tag "${merge_group_id}"
  label 'mem_max'
  label 'long_running'
  publishDir "${publish_merge_base}/${merge_group_id}"
  input:
    tuple val(merge_group_id), val(library_ids), path(processed_files), val(has_adt)
  output:
    tuple path(merged_sce_file), val(merge_group_id), val(has_adt)
  script:
    def input_library_ids = library_ids.join(',')
    def input_sces = processed_files.join(',')
    def merged_sce_file = "${merge_group_id}_merged.rds"
    """
    merge_sces.R \
      --input_library_ids "${input_library_ids}" \
      --input_sce_files "${input_sces}" \
      --output_sce_file "${merged_sce_file}" \
      --n_hvg ${params.num_hvg} \
      --threads ${task.cpus}
    """
  stub:
    def merged_sce_file = "${merge_group_id}_merged.rds"
    """
    touch ${merged_sce_file}
    """

}

// create merge report
process generate_merge_report {
  container ghcr.io/alexslemonade/scpcatools-reports:edge
  tag "${merge_group_id}"
  publishDir "${params.results_dir}/${merge_group_id}/merged"
  label 'mem_max'
  input:
    tuple path(merged_sce_file), val(merge_group_id), val(has_adt)
    path(report_template)
  output:
    path(merge_report)
  script:
    def merge_report = "${merge_group_id}_merged-summary-report.html"
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
    def merge_report = "${merge_group_id}_merged-summary-report.html"
    """
    touch ${merge_report}
    """
}

process export_anndata {
    container ghcr.io/alexslemonade/scpcatools-anndata:edge
    label 'mem_max'
    label 'long_running'
    tag "${merge_group_id}"
    publishDir "${params.results_dir}/${merge_group_id}/merged", mode: 'copy'
    input:
      tuple path(merged_sce_file), val(merge_group_id), val(has_adt)
    output:
      tuple val(merge_group_id), path("${merge_group_id}_merged_*.h5ad")
    script:
      def rna_h5ad_file = "${merge_group_id}_merged_rna.h5ad"
      def feature_h5ad_file = "${merge_group_id}_merged_adt.h5ad"
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
      def rna_h5ad_file = "${merge_group_id}_merged_rna.h5ad"
      def feature_h5ad_file = "${merge_group_id}_merged_adt.h5ad"
      """
      touch ${rna_h5ad_file}
      ${has_adt ? "touch ${feature_h5ad_file}" : ''}
      """
}

workflow merge_sce{
  take:
    project_ch  // Channel of [project_id, project_dir]
  main:
    // get all SCE files by project
    // this will be a channel of [project_id, [library_ids], [processed_sce_files], has_adt]
    libraries_ch = project_ch
      .map{project_id, project_dir -> {
        def processed_files = files("${project_dir}/**_processed.rds")
        def library_ids = processed_files.name.collect{it.replace('_processed.rds', '')}
        def has_adt = file("${project_dir}/**_processed_adt.h5ad") as Boolean // true if there are any adt files
        return [project_id, library_ids, processed_files, has_adt]
      }
    }

    // get all projects that contain at least one library with CITEseq
    adt_projects = libraries_ch
      .filter{it.technology.startsWith('CITEseq')}
      .collect{it.project_id}
      .map{it.unique()}

    multiplex_projects = libraries_ch
      .filter{it.technology.startsWith('cellhash')}
      .collect{it.project_id}
      .map{it.unique()}

    filtered_libraries_ch = libraries_ch
      // only include single-cell/single-nuclei which ensures we don't try to merge libraries from spatial or bulk data
      .filter{it.seq_unit in ['cell', 'nucleus']}
      // remove any multiplexed projects
      // future todo: only filter library ids that are multiplexed, but keep all other non-multiplexed libraries
      .branch{
        multiplexed: it.project_id in multiplex_projects.getVal()
        single_sample: true
      }

    filtered_libraries_ch.multiplexed
      .unique{ it.project_id }
      .subscribe{
        log.warn("Not merging ${it.project_id} because it contains multiplexed libraries.")
      }

    // print out warning message for any libraries not included in merging
    filtered_libraries_ch.single_sample
      .map{[
        it.library_id,
        file("${params.results_dir}/${it.project_id}/${it.sample_id}/${it.library_id}_processed.rds")
      ]}
    .filter{!(it[1].exists() && it[1].size() > 0)}
    .subscribe{
      log.warn("Processed files do not exist for ${it[0]}. This library will not be included in the merged object.")
    }

    grouped_libraries_ch = filtered_libraries_ch.single_sample
      // create tuple of [project id, library_id, processed_sce_file]
      .map{[
        it.project_id,
        it.library_id,
        file("${params.results_dir}/${it.project_id}/${it.sample_id}/${it.library_id}_processed.rds")
      ]}
      // only include libraries that have been processed through scpca-nf and aren't empty
      .filter{it[2].exists() && it[2].size() > 0}
      // only one row per library ID, this removes all the duplicates that may be present due to CITE/hashing
      .unique()
      // group tuple by project id: [project_id, [library_id1, library_id2, ...], [sce_file1, sce_file2, ...]]
      .groupTuple(by: 0)
      .branch{
        has_merge: file("${publish_merge_base}/${it[0]}/${it[0]}_merged.rds").exists() && params.reuse_merge
        make_merge: true
      }

    pre_merged_ch = grouped_libraries_ch.has_merge
      .map{[ // merge file, project id, has adt
        file("${publish_merge_base}/${it[0]}/${it[0]}_merged.rds"),
        it[0],
        it[1]
      ]}

    // merge SCE objects
    merge_sce(grouped_libraries_ch.make_merge)

    merged_ch = merge_sce.out.mix(pre_merged_ch)


    // generate merge report
    generate_merge_report(merged_ch, file(merge_report_template))

    // export merged objects to AnnData
    export_anndata(merged_ch)
}
