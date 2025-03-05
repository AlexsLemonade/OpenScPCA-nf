#!/usr/bin/env Rscript

# This script is used to assign cell type annotations to Ewing sarcoma libraries in SCPCP000015
# Tumor cells are assigned based on those with AUC values above specified thresholds for specific gene sets
# Tumor cells are then classified into EWS-high, EWS-low, and EWS-high proliferative
# Normal cells are all non-tumor cells and are labeled with the consensus cell type

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--sce_file"),
    type = "character",
    help = "Path to RDS file containing a processed SingleCellExperiment object annotate."
  ),
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
    opt_str = c("--auc_table"),
    type = "character",
    default = NULL,
    help = "Path to TSV file containing the AUC values to use as thresholds for assigning tumor cell states."
  ),
  make_option(
    opt_str = c("--cell_state_markers_file"),
    type = "character",
    default = NULL,
    help = "Path to TSV file with marker genes to use for labeling EWS-high proliferative cells.
      Must contain a `cell_state` and `ensembl_gene_id` column.
      Marker genes that have `cell_state == proliferative` will be used."
  ),
  make_option(
    opt_str = c("--output_file"),
    type = "character",
    help = "Path to file where results will be saved"
  )
)

# Parse options
opt <- parse_args(OptionParser(option_list = option_list))

# Set up -----------------------------------------------------------------------

# make sure input files exist
stopifnot(
  "sce file does not exist" = file.exists(opt$sce_file),
  "consensus cell types file does not exist" = file.exists(opt$consensus_celltype_file),
  "AUCell results file does not exist" = file.exists(opt$aucell_results_file),
  "auc_table file does not exist" = file.exists(opt$auc_table),
  "cell_state_markers_file does not exist" = file.exists(opt$cell_state_markers_file)
)

# load SCE
suppressPackageStartupMessages({
  library(SingleCellExperiment)
})

# read in files
sce <- readr::read_rds(opt$sce_file)
consensus_df <- readr::read_tsv(opt$consensus_celltype_file)
aucell_results_df <- readr::read_tsv(opt$aucell_results_file)
auc_threshold_df <- readr::read_tsv(opt$auc_table)
cell_state_markers_df <- readr::read_tsv(opt$cell_state_markers_file)


# assign normal cell types using consensus cell types --------------------------
assignment_df <- consensus_df |>
  dplyr::mutate(
    custom_annotation = dplyr::if_else(
      !is.na(consensus_ontology),
      consensus_annotation,
      "unknown"
    )
  )


# assign tumor cells and tumor cell states -------------------------------------
# pull out tumor cell states
tumor_cell_states <- unique(auc_threshold_df$cell_type)

# for each cell state get a list of cells that belong to that cell state using AUCell results
# then update the existing custom annotation column to label those cells with that cell state
tumor_cell_states |>
  purrr::walk(\(state){
    # get a list of all gene sets that should be used to classify that cell state
    geneset_auc_list <- auc_threshold_df |>
      dplyr::filter(cell_type == state) |>
      dplyr::select(gene_set, auc_threshold) |>
      tibble::deframe()

    # get cells that meet all criteria, e.g., have auc > threshold for all gene sets
    cells <- geneset_auc_list |>
      purrr::imap(\(auc_threshold, name){
        aucell_results_df |>
          dplyr::filter(gene_set == name & auc > auc_threshold) |>
          dplyr::pull(barcodes)
      }) |>
      purrr::reduce(intersect)

    # figure out which cells these are
    cell_state_idx <- which(assignment_df$barcodes %in% cells)

    # label the cells with that cell state
    # modify the data frame in place with <<-
    assignment_df$custom_annotation[cell_state_idx] <<- state
  })

# Label proliferative tumor cells ----------------------------------------------

# get proliferative marker genes
proliferative_markers <- cell_state_markers_df |>
  dplyr::filter(cell_state == "proliferative") |>
  dplyr::pull(ensembl_gene_id)

# calculate the mean expression of all genes for all cells
mean_exp <- logcounts(sce[proliferative_markers, ]) |>
  as.matrix() |>
  t() |>
  rowMeans()

# get cells with mean > 0
proliferative_cells <- names(mean_exp)[mean_exp > 0]

# create final assignments
assignment_df <- assignment_df |>
  dplyr::mutate(
    # assign proliferative based on being EWS-high and mean proliferative > 0
    custom_annotation = dplyr::if_else(
      barcodes %in% proliferative_cells & custom_annotation == "tumor EWS-high",
      "tumor EWS-high proliferative",
      custom_annotation
    ),
    # add ontology column
    custom_ontology = dplyr::if_else(
      custom_annotation == consensus_annotation,
      consensus_ontology,
      custom_annotation
    )
  )

# export final annotations
readr::write_tsv(assignment_df, opt$output_file)
