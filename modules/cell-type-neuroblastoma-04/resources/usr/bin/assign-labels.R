#!/usr/bin/env Rscript
#
# This script assigns final annotations to a given neuroblastoma library based on the
# singler, scanvi/scarches, and consensus annotations.
# For full information on how these annotations are assigned, please see here:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/main/analyses/cell-type-neuroblastoma-04/README.md#annotation-approach
#
# This script was adapted from:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/b2e8e5a042e13a0c1429eb64e1d16c01e1781400/analyses/cell-type-neuroblastoma-04/final-annotation.Rmd


library(optparse)


option_list <- list(
  make_option(
    opt_str = c("--singler_tsv"),
    type = "character",
    default = "",
    help = "Path to TSV with SingleR annotations for a given library"
  ),
  make_option(
    opt_str = c("--scanvi_tsv"),
    type = "character",
    default = "",
    help = "Path to TSV with scANVI/scArches annotations for a given library"
  ),
  make_option(
    opt_str = c("--consensus_tsv"),
    type = "character",
    default = "",
    help = "Path to TSV with consensus annotations for a given library"
  ),
  make_option(
    opt_str = c("--nbatlas_label_tsv"),
    type = "character",
    default = "",
    help = "Path to TSV mapping NBAtlas labels to their family label"
  ),
  make_option(
    opt_str = c("--nbatlas_ontology_tsv"),
    type = "character",
    default = "",
    help = "Path to TSV mapping NBAtlas labels to ontology ids"
  ),
  make_option(
    opt_str = c("--consensus_validation_tsv"),
    type = "character",
    default = "",
    help = "Path to TSV file with consensus validation groups and ontology ids NBAtlas labels to ontology ids"
  ),
  make_option(
    opt_str = c("--annotations_tsv"),
    type = "character",
    help = "Path to output tsv file with final annotations for a given library"
  ),
  make_option(
    opt_str = c("--scanvi_posterior_threshold"),
    type = "numeric",
    default = 0.75,
    help = "Posterior probability threshold for labeling cells with scANVI/scArches"
  )
)

# Set up --------------------

# Parse options and check arguments
opts <- parse_args(OptionParser(option_list = option_list))

stopifnot(
  "singler_tsv does not exist" = file.exists(opts$singler_tsv),
  "scanvi_tsv does not exist" = file.exists(opts$scanvi_tsv),
  "consensus_tsv does not exist" = file.exists(opts$consensus_tsv),
  "nbatlas_label_tsv does not exist" = file.exists(opts$nbatlas_label_tsv),
  "nbatlas_ontology_tsv does not exist" = file.exists(opts$nbatlas_ontology_tsv),
  "consensus_validation_tsv does not exist" = file.exists(opts$consensus_validation_tsv),
  "annotations_tsv must be provided" = !is.null(opts$annotations_tsv),
  "scanvi_posterior_threshold should be numeric between 0-1" = dplyr::between(opts$scanvi_posterior_threshold, 0, 1)
)


#' Prepare data frame of scANVI or SingleR labels for annotation
#'
#' @param df Data frame to prepare
#' @param annot_type "singler" or "scanvi"
#' @param ontology_df Data frame of ontology ids
#' @param label_map_df Data frame mapping labels to family labels
#'
#' @returns Wide data frame with ontologies and family labels for the given annotation type
prep_for_annotation <- function(
    df,
    annot_type,
    ontology_df,
    label_map_df) {
  df |>
    dplyr::rename(label = annot_type) |>
    ####### Join in the family labels
    dplyr::left_join(label_map_df, by = c("label" = "NBAtlas_label")) |>
    dplyr::rename(family = NBAtlas_family) |>
    ######### Obtain LABEL ontologies
    dplyr::left_join(ontology_df, by = c("label" = "NBAtlas_label")) |>
    dplyr::rename(label_ontology = CL_ontology_id) |>
    ######## Obtain FAMILY ontologies
    dplyr::left_join(ontology_df, by = c("family" = "NBAtlas_label")) |>
    dplyr::rename(family_ontology = CL_ontology_id) |>
    # rename columns to start with `annot_type`
    dplyr::rename_with(\(x) {
      paste(annot_type, x, sep = "_")
    }, -barcodes)
}

# Define vector of tumor-like cell types to support assigning
# Neuroendocrine labels
tumorlike_cells <- c("Schwann", "Stromal other", "Fibroblast")


# Read and format cell type data frames -----------------------
singler_df <- readr::read_tsv(opts$singler_tsv) |>
  dplyr::mutate(
    # recode NA -> "Unknown" and NE -> "Neuroendocrine"
    singler = dplyr::case_when(
      is.na(pruned.labels) ~ "Unknown",
      pruned.labels == "NE" ~ "Neuroendocrine",
      .default = pruned.labels
    )
  ) |>
  dplyr::select(barcodes, singler)

scanvi_df <- readr::read_tsv(opts$scanvi_tsv) |>
  # pull out barcodes from cell_id
  tidyr::separate(cell_id, into = c("library_id", "barcodes"), sep = "-") |>
  # get the posterior for the predicted cell type so we can filter on threshold as needed
  dplyr::select(
    barcodes,
    scanvi = scanvi_prediction,
    starts_with("pp_")
  ) |>
  tidyr::pivot_longer(
    starts_with("pp_"),
    names_to = "posterior_celltype",
    values_to = "posterior"
  ) |>
  dplyr::mutate(posterior_celltype = stringr::str_remove(posterior_celltype, "^pp_")) |>
  dplyr::filter(scanvi == posterior_celltype) |>
  # recode to Unknown if below the threshold, and NE -> Neuroendocrine
  dplyr::mutate(scanvi = dplyr::case_when(
    posterior < opts$scanvi_posterior_threshold ~ "Unknown",
    scanvi == "NE" ~ "Neuroendocrine",
    .default = scanvi
  )) |>
  dplyr::select(barcodes, scanvi)


consensus_df <- readr::read_tsv(opts$consensus_tsv) |>
  dplyr::select(
    barcodes,
    consensus = consensus_annotation,
    consensus_ontology
  )

# Read helper data frames -----------------------

label_map_df <- readr::read_tsv(opts$nbatlas_label_tsv)
ontology_df <- readr::read_tsv(opts$nbatlas_ontology_tsv)

# supports joining on both families and labels without duplicating columns
ontology_slim_df <- ontology_df |>
  dplyr::select(-CL_annotation)

validation_df <- readr::read_tsv(opts$consensus_validation_tsv) |>
  dplyr::rename(
    consensus = consensus_annotation,
    consensus_family_label = validation_group_annotation,
    consensus_family_ontology = validation_group_ontology
  )

# Prepare data for annotation -----------------------------------------
singler_annotation_df <- prep_for_annotation(
  singler_df,
  "singler",
  ontology_slim_df,
  label_map_df
)
scanvi_annotation_df <- prep_for_annotation(
  scanvi_df,
  "scanvi",
  ontology_slim_df,
  label_map_df
)

annotation_df <- consensus_df |>
  dplyr::left_join(singler_annotation_df, by = "barcodes") |>
  dplyr::left_join(scanvi_annotation_df, by = "barcodes") |>
  dplyr::left_join(validation_df, by = c("consensus", "consensus_ontology")) |>
  dplyr::select(barcodes, starts_with("consensus"), starts_with("singler"), starts_with("scanvi"))


# Assign labels -----------------------------------------
final_annotation_df <- annotation_df |>
  dplyr::mutate(
    # For all comparisons, make sure we aren't comparing NA to NA and getting TRUE
    final_label = dplyr::case_when(
      ########### Check for exact match between SingleR/scANVI
      !is.na(scanvi_label_ontology) & singler_label_ontology == scanvi_label_ontology ~ scanvi_label,
      ########### Check for family match between SingleR/scANVI
      !is.na(scanvi_family_ontology) & singler_family_ontology == scanvi_family_ontology ~ scanvi_family,
      ########## Now use agreement with consensus to assign a label: first by label, and then by family
      !is.na(consensus_ontology) & singler_label_ontology == consensus_ontology ~ singler_label,
      !is.na(consensus_ontology) & scanvi_label_ontology == consensus_ontology ~ scanvi_label,
      !is.na(consensus_family_ontology) & singler_family_ontology == consensus_family_ontology ~ singler_family,
      !is.na(consensus_family_ontology) & scanvi_family_ontology == consensus_family_ontology ~ scanvi_family,
      ########## Assign Neuroendocrine where possible; for this step, we refer to NBAtlas labels directly since
      # the `tumorlike_cells` don't all have ontology ids
      is.na(consensus_ontology) & singler_label == "Neuroendocrine" & scanvi_label %in% tumorlike_cells ~ "Neuroendocrine",
      is.na(consensus_ontology) & scanvi_label == "Neuroendocrine" & singler_label %in% tumorlike_cells ~ "Neuroendocrine",
      # Everything else is Unknown
      .default = "Unknown"
    )
  ) |>
  # Now, we can bring the final ontologies into the data frame
  dplyr::inner_join(
    ontology_df |> dplyr::rename(final_label = NBAtlas_label, final_ontology_id = CL_ontology_id),
    by = "final_label"
  ) |>
  # finalize columns for export
  dplyr::mutate(
    cell_class = dplyr::case_when(
      final_label == "Neuroendocrine" ~ "tumor",
      final_label == "Unknown" ~ "unknown",
      .default = "normal"
    )
  ) |>
  # rename for final export
  dplyr::select(
    barcodes,
    neuroblastoma_04_annotation = final_label,
    neuroblastoma_04_ontology = final_ontology_id,
    neuroblastoma_04_ontology_label = CL_annotation,
    singler_label,
    scanvi_label,
    cell_class
  )


# Export to TSV ---------------------------
readr::write_tsv(final_annotation_df, opts$annotations_tsv)
