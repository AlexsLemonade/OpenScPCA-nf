#!/usr/bin/env nextflow

// Workflow to merge SCE objects into a single object.
// This workflow does NOT perform integration, i.e. batch correction.

// module parameters
params.reuse_merge = false
params.max_merge_libraries = 75 // maximum number of libraries to merge (current number is a guess, based on 59 working, but 104 not)
params.num_hvg = 2000 // number of HVGs to select

// merge workflow variables
def module_name = "merge-sce"
def publish_merge_base = "${params.results_bucket}/${params.release_prefix}/${module_name}"
def merge_report_template = "${projectDir}/modules/merge-sce/resources/merge-report.rmd"


// merge individual SCE objects into one SCE object
process merge_group {
  container "ghcr.io/alexslemonade/scpcatools-slim:v0.4.0"
  tag "${merge_group_id}"
  label 'mem_max'
  label 'long_running'
  publishDir "${publish_merge_base}/${merge_group_id}"
  input:
    tuple val(merge_group_id), val(library_ids), path(processed_files)
  output:
    tuple val(merge_group_id), path(merged_sce_file)
  script:
    input_library_ids = library_ids.join(',')
    input_sces = processed_files.join(',')
    merged_sce_file = "${merge_group_id}_merged.rds"
    """
    merge_sces.R \
      --input_library_ids '${input_library_ids}' \
      --input_sce_files '${input_sces}' \
      --output_sce_file '${merged_sce_file}' \
      --n_hvg ${params.num_hvg} \
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
  container "ghcr.io/alexslemonade/scpcatools-reports:v0.4.0"
  tag "${merge_group_id}"
  publishDir "${publish_merge_base}/${merge_group_id}"
  label 'mem_max'
  input:
    tuple val(merge_group_id), path(merged_sce_file)
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
    container "ghcr.io/alexslemonade/scpcatools-anndata:v0.4.0"
    label 'mem_max'
    label 'long_running'
    tag "${merge_group_id}"
    publishDir "${publish_merge_base}/${merge_group_id}"
    input:
      tuple val(merge_group_id), path(merged_sce_file)
    output:
      tuple val(merge_group_id), path("${merge_group_id}_merged_*.h5ad")
    script:
      rna_h5ad_file = "${merge_group_id}_merged_rna.h5ad"
      feature_h5ad_file = "${merge_group_id}_merged_adt.h5ad"
      """
      sce_to_anndata.R \
        --input_sce_file ${merged_sce_file} \
        --output_rna_h5 ${rna_h5ad_file} \
        --feature_name adt \
        --output_feature_h5 ${feature_h5ad_file} \
        --is_merged \

      # move normalized counts to X in AnnData
      reformat_anndata.py --anndata_file ${rna_h5ad_file} --hvg_name "merged_highly_variable_genes"
      if [ -f ${feature_h5ad_file} ]; then
        reformat_anndata.py --anndata_file ${feature_h5ad_file} --hvg_name "none"
      fi
      """
    stub:
      rna_h5ad_file = "${merge_group_id}_merged_rna.h5ad"
      feature_h5ad_file = "${merge_group_id}_merged_adt.h5ad"
      """
      touch ${rna_h5ad_file}
      touch ${feature_h5ad_file}
      """
}

workflow merge_sce {
  take:
    sample_ch  // Channel of [sample_id, project_id, file(sample_dir)]
  main:
    // create a channel of [project_id, file(project_dir)] with one per project
    project_ch = sample_ch
      .map{[it[1], it[2].parent]} // parent of the sample_dir is the project_dir
      .unique()

    project_branch = project_ch
      .branch{
        // multiplexed libraries are subdirectories with more than one sample id
        multiplexed: files(it[1] / "*", type: "dir").any{it.name =~ /SCPCS\d+_SCPCS\d+/}
        single_sample: true
      }

    // get all SCE files by project
    // this will be a channel of [project_id, [library_ids], [processed_sce_files]]
    libraries_ch = project_branch.single_sample
      .map{ project_id, project_dir ->
        def processed_files = Utils.getLibraryFiles(project_dir, format: "sce", process_level: "processed")
        def library_ids = processed_files.collect{it.name.replace('_processed.rds', '')}
        return [project_id, library_ids, processed_files]
      }
      .branch{
        // check the number of libraries
        mergeable: it[1].size() < params.max_merge_libraries
        oversized: true
      }

    project_branch.multiplexed
      .subscribe{
        log.warn("Not merging ${it[0]} because it contains multiplexed libraries.")
      }

    libraries_ch.oversized
      .subscribe{
        log.warn("Not merging ${it[0]} because it has too many libraries.")
      }

    libraries_branch = libraries_ch.mergeable
      .branch{
        has_merge: params.reuse_merge && file("${publish_merge_base}/${it[0]}/${it[0]}_merged.rds").exists()
        make_merge: true
      }

    pre_merged_ch = libraries_branch.has_merge
      .map{[ // [project id, merged_file] to match the output of merge_group
        it[0],
        file("${publish_merge_base}/${it[0]}/${it[0]}_merged.rds")
      ]}

    // merge SCE objects
    merge_group(libraries_branch.make_merge)

    merged_ch = merge_group.out.mix(pre_merged_ch)

    // generate merge report
    generate_merge_report(merged_ch, file(merge_report_template))

    // export merged objects to AnnData
    export_anndata(merged_ch)

  emit:
    merged_ch // Channel of [project_id, file(merged_sce_file)]
}
