#!/usr/bin/env Rscript

# This script is used to assign cell type annotations to Ewing sarcoma libraries in SCPCP000015
# Tumor cells are assigned based on those with AUC values above specified thresholds for specific gene sets
# Tumor cells are then classified into EWS-high, EWS-low
# Normal cells are all non-tumor cells and are labeled with the consensus cell type
# if tumor cells have mean expression of proliferative markers > 0 "proliferative" will be appended to cell type label

# `ewing_annotation` and `ewing_ontology` columns in the output TSV file will contain the final cell type labels

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--consensus_celltype_file"),
    type = "character",
    help = "Path to TSV file containing consensus cell type labels for a single library."
  ),
  make_option(
    opt_str = c("--aucell_results_file"),
    type = "character",
    default = NULL,
    help = "Path to TSV file containing the AUC values for a set of gene sets output by aucell.R"
  ),
  make_option(
    opt_str = c("--auc_thresholds_file"),
    type = "character",
    default = NULL,
    help = "Path to TSV file containing the AUC values to use as thresholds for assigning tumor cell states."
  ),
  make_option(
    opt_str = c("--mean_gene_expression_file"),
    type = "character",
    default = NULL,
    help = "Path to TSV file with mean expression of custom marker gene sets.
      Cells with mean expression of proliferative markers > 0 will be labeled with proliferative."
  ),
  make_option(
    opt_str = c("--output_file"),
    type = "character",
    help = "Path to file where results will be saved as a tsv"
  )
)

# Parse options
opt <- parse_args(OptionParser(option_list = option_list))

# Set up -----------------------------------------------------------------------

# make sure input files exist
stopifnot(
  "consensus cell types file does not exist" = file.exists(opt$consensus_celltype_file),
  "AUCell results file does not exist" = file.exists(opt$aucell_results_file),
  "auc_thresholds_file file does not exist" = file.exists(opt$auc_thresholds_file),
  "mean_gene_expression_file does not exist" = file.exists(opt$mean_gene_expression_file)
)

# read in files
consensus_df <- readr::read_tsv(opt$consensus_celltype_file)
aucell_results_df <- readr::read_tsv(opt$aucell_results_file)
auc_threshold_df <- readr::read_tsv(opt$auc_thresholds_file)
mean_exp_df <- readr::read_tsv(opt$mean_gene_expression_file)


# assign tumor cells and tumor cell states -------------------------------------
# pull out tumor cell states
tumor_cell_states <- unique(auc_threshold_df$cell_type)

# for each cell state get a list of cells that belong to that cell state using AUCell results
cell_state_df <- tumor_cell_states |>
  purrr::map(\(state){
    # get a list of all gene sets that should be used to classify that cell state
    geneset_auc_df <- auc_threshold_df |>
      dplyr::filter(cell_type == state) |>
      dplyr::select(gs_name = gene_set, auc_threshold)

    # get cells that meet all criteria, e.g., have auc > threshold for all gene sets
    cells <- geneset_auc_df |>
      purrr::pmap(\(gs_name, auc_threshold){
        aucell_results_df |>
          dplyr::filter(gene_set == gs_name & auc > auc_threshold) |>
          dplyr::pull(barcodes)
      }) |>
      purrr::reduce(intersect)

    if (length(cells) > 0) {
      df <- data.frame(
        barcodes = cells,
        ewing_annotation = state
      )
    } else {
      df <- data.frame(
        ewing_annotation = state,
        barcodes = NA
      )
    }
  }) |>
  purrr::list_rbind() |>
  tidyr::drop_na() |> # get rid of any states that don't have any assigned barcodes
  dplyr::mutate(barcodes = as.character(barcodes)) |> # make sure its a character for joining later
  dplyr::group_by(barcodes) |>
  # account for anything that could be in both groups
  dplyr::summarise(
    ewing_annotation = paste0(ewing_annotation, collapse = ",")
  )

# add custom annotations back with original annotations
# any cells that aren't tumor cells will be NA
assignment_df <- consensus_df |>
  dplyr::left_join(cell_state_df, by = "barcodes")

# assign normal cell types using consensus cell types --------------------------

assignment_df <- assignment_df |>
  dplyr::mutate(
    # use consensus annotation if custom is missing
    ewing_annotation = dplyr::coalesce(ewing_annotation, consensus_annotation)
  )

# Label proliferative tumor cells ----------------------------------------------

# get cells with proliferative mean > 0
proliferative_cells <- mean_exp_df |>
  dplyr::filter(proliferative_mean_expression > 0) |>
  dplyr::pull(barcodes)

# create final assignments
assignment_df <- assignment_df |>
  dplyr::mutate(
    # add proliferative label to tumor cells if mean proliferative > 0
    ewing_annotation = dplyr::if_else(
      barcodes %in% proliferative_cells & stringr::str_detect(ewing_annotation, "tumor"),
      glue::glue("{ewing_annotation} proliferative"),
      ewing_annotation
    ),
    # add ontology column
    ewing_ontology = dplyr::if_else(
      ewing_annotation == consensus_annotation,
      consensus_ontology,
      ewing_annotation
    )
  )

# export final annotations
readr::write_tsv(assignment_df, opt$output_file)
