#!/usr/bin/env nextflow

// Workflow to format and export openscpca annotations

process format_annotations {
  container params.scpcatools_slim_container
  tag "${sample_id}"
  label 'mem_8'
  publishDir "${params.annotations_bucket}/${params.release_prefix}/${project_id}/${sample_id}", mode: 'copy'
  input:
    tuple val(sample_id),
          val(project_id),
          path(annotations_tsv_files),
          val(annotation_column),
          val(ontology_column),
          val(module_name)
  output:
    tuple val(sample_id),
          val(project_id),
          path(json_files)
  script:
    library_ids = annotations_tsv_files.collect{(it.name =~ /SCPCL\d{6}/)[0]}
    json_files = library_ids.collect{"${it}_openscpca-annotations.json"}
    ontology_included = "${ontology_column}" != "NONE"
    """
    for library_id in ${library_ids.join(" ")};do
      # get the input files for the library id
      annotations_file=\$(ls ${annotations_tsv_files} | grep "\${library_id}")

      export-celltype-json.R \
        --annotations_tsv_file \$annotations_file \
        --annotation_column "${annotation_column}" \
        ${ontology_included ? "--ontology_column  '${ontology_column}'" : ''} \
        --module_name ${module_name} \
        --release_date ${params.release_prefix} \
        --openscpca_nf_version ${workflow.manifest.version} \
        --output_json_file \${library_id}_openscpca-annotations.json
    done
    """

  stub:
    library_ids = annotations_tsv_files.collect{(it.name =~ /SCPCL\d{6}/)[0]}
    json_files = library_ids.collect{"${it}_openscpca-annotations.json"}
    """
    for library_id in ${library_ids.join(" ")};do
      touch \${library_id}_openscpca-annotations.json
    done
    """
}

workflow export_annotations {
  take:
    celltype_ch  // [sample_id, project_id, [cell type assignment files], annotation column, ontology column, module name]
  main:
    // export json
    format_annotations(celltype_ch)

  emit:
    format_annotations.out // [sample id, project id, annotations json]
}
