#!/usr/bin/env Rscript

# This script is used to grab the cell type annotations from the
# colData from a SCE object and save them to a TSV file

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--input_sce_file"),
    type = "character",
    help = "Path to RDS file containing a processed SingleCellExperiment object from scpca-nf"
  ),
  make_option(
    opt_str = c("--output_file"),
    type = "character",
    help = "Path to file where colData will be saved, must end in `.tsv`"
  )
)

# Parse options
opt <- parse_args(OptionParser(option_list = option_list))

# Set up -----------------------------------------------------------------------

# make sure input files exist
stopifnot(
  "sce file does not exist" = file.exists(opt$input_sce_file)
)

# load SCE
suppressPackageStartupMessages({
  library(SingleCellExperiment)
})

# Extract colData --------------------------------------------------------------

# read in sce
sce <- readr::read_rds(opt$input_sce_file)

# extract ids
library_id <- metadata(sce)$library_id
# account for multiplexed libraries that have multiple samples
# for now just combine sample ids into a single string and don't worry about demultiplexing
sample_id <- metadata(sce)$sample_id |>
  paste0(collapse = ";")
project_id <- metadata(sce)$project_id

# check if cell line since cell lines don't have any cell type assignments
# account for having more than one sample and a list of sample types
# all sample types should be the same theoretically
is_cell_line <- all(metadata(sce)$sample_type == "cell line")

# grab coldata
coldata_df <- colData(sce) |>
  as.data.frame() |>
  # add unique sample/library information
  dplyr::mutate(
    project_id = project_id,
    sample_id = sample_id,
    library_id = library_id,
    # add in sample type to make sure we don't assign consensus cell types to cell lines
    # all samples in a library should be the same sample type so use unique
    sample_type = unique(sample_type)
  )

# only select sample info and cell type info, we don't need the rest of the coldata
# if sample is cell line, fill in celltype columns with NA
if (is_cell_line) {
  celltype_df <- coldata_df |>
    dplyr::select(
      project_id,
      sample_id,
      library_id,
      barcodes,
      sample_type
    ) |>
    dplyr::mutate(
      singler_celltype_ontology = NA,
      singler_celltype_annotation = NA,
      cellassign_celltype_annotation = NA
    )
} else {
  # otherwise select the cell type columns
  celltype_df <- coldata_df |>
    dplyr::select(
      project_id,
      sample_id,
      library_id,
      barcodes,
      sample_type,
      contains("celltype") # get both singler and cellassign with ontology
    )
}

# save tsv
readr::write_tsv(celltype_df, opt$output_file)
