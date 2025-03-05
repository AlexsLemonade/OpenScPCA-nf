#!/usr/bin/env Rscript

# This script is used to get the mean expression of the all custom marker gene sets

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--sce_file"),
    type = "character",
    help = "Path to RDS file containing a processed SingleCellExperiment object"
  ),
  make_option(
    opt_str = c("--cell_state_markers_file"),
    type = "character",
    default = NULL,
    help = "Path to TSV file with custom marker genes.
      Must contain a `cell_state` and `ensembl_gene_id` column.
      One column for each unique `cell_state` with the mean expression of all marker genes for that `cell_state` will be included in the output."
  ),
  make_option(
    opt_str = c("--output_file"),
    type = "character",
    help = "Path to file where results will be saved as a TSV"
  )
)

# Parse options
opt <- parse_args(OptionParser(option_list = option_list))

# Set up -----------------------------------------------------------------------

# make sure input files exist
stopifnot(
  "sce file must be specified using `--sce_file`" = !is.null(opt$sce_file)
)

stopifnot(
  "sce file does not exist" = file.exists(opt$sce_file),
  "cell_state_markers_file does not exist" = file.exists(opt$cell_state_markers_file)
)

# load SCE
suppressPackageStartupMessages({
  library(SingleCellExperiment)
})

# read in files
sce <- readr::read_rds(opt$sce_file)
cell_state_markers_df <- readr::read_tsv(opt$cell_state_markers_file)

# Calculate mean expression ----------------------------------------------------
# get all cell states
cell_states <- unique(cell_state_markers_df$cell_state)

# construct a data frame with mean expression of all marker genes in each cell state
mean_exp_df <- cell_states |>
  purrr::map(\(state){
    # marker genes for a given state
    marker_gene_list <- cell_state_markers_df |>
      dplyr::filter(cell_state == state) |>
      dplyr::pull(ensembl_gene_id)

    # calculate the mean expression of all genes for all cells
    mean_exp <- logcounts(sce[marker_gene_list, ]) |>
      colMeans()
  }) |>
  dplyr::bind_cols() |>
  # add barcodes column
  dplyr::mutate(
    barcodes = colnames(sce),
    .before = 0
  )

# rename columns based on cell state
colnames(mean_exp_df) <- c("barcodes", glue::glue("{cell_states}_mean_expression"))

# export
readr::write_tsv(mean_exp_df, opt$output_file)
