#!/usr/bin/env Rscript

# This script is used to create a JSON file of annotations for a single library
# JSON file will include barcodes, annotation column, ontology column (if provided),
# openscpca-nf version, data release data, and module name

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--annotations_tsv_file"),
    type = "character",
    help = "Path to TSV file with cell type annotations"
  ),
  make_option(
    opt_str = c("--annotation_column"),
    type = "character",
    help = "Name of the column containing the cell type annotations to use for openscpca_celltype_annotation"
  ),
  make_option(
    opt_str = c("--ontology_column"),
    default = "",
    type = "character",
    help = "Name of the column containing the cell type ontology IDs to use for openscpca_celltype_ontology"
  ),
  make_option(
    opt_str = c("--module_name"),
    type = "character",
    help = "Name of original module in OpenScPCA-analysis"
  ),
  make_option(
    opt_str = c("--release_date"),
    type = "character",
    help = "Release date of data used when generating annotations"
  ),
  make_option(
    opt_str = c("--openscpca_nf_version"),
    type = "character",
    help = "Version of OpenScPCA-nf workflow"
  ),
  make_option(
    opt_str = "--output_json_file",
    type = "character",
    help = "Path to JSON file to save cell type annotations"
  )
)

# Parse options
opt <- parse_args(OptionParser(option_list = option_list))

# Set up -----------------------------------------------------------------------

# make sure input/output exist
stopifnot(
  "annotations TSV file does not exist" = file.exists(opt$annotations_tsv_file),
  "annotation column must be provided" = !is.null(opt$annotation_column),
  "module name must be provided" = !is.null(opt$module_name),
  "release date must be provided" = !is.null(opt$release_date),
  "openscpca-nf version must be provided" = !is.null(opt$openscpca_nf_version),
  "output json file must end in .json" = stringr::str_ends(opt$output_json_file, "\\.json")
)

# read in annotations
annotations_df <- readr::read_tsv(opt$annotations_tsv_file)

# check that barcodes and annotation column exist
stopifnot(
  "barcodes column must be present in provided TSV file" = "barcodes" %in% colnames(annotations_df),
  "annotation column is not present in provided TSV file" = opt$annotation_column %in% colnames(annotations_df)
)

# check for ontology ids if provided
if (!is.null(opt$ontology_column)) {
  stopifnot(
    "ontology column is not present in provided TSV file" = opt$ontology_column %in% colnames(annotations_df)
  )
  ontology_ids <- annotations_df[[opt$ontology_column]]
} else {
  ontology_ids <- NA
}

# build json contents
json_contents <- list(
  module_name = opt$module_name,
  openscpca_nf_version = opt$openscpca_nf_version,
  release_date = opt$release_date,
  barcodes = annotations_df$barcodes,
  openscpca_celltype_annotation = annotations_df[[opt$annotation_column]],
  openscpca_celltype_ontology = ontology_ids
)

# export json file
jsonlite::write_json(
  json_contents,
  path = opt$output_json_file,
  simplifyVector = TRUE,
  auto_unbox = TRUE,
  pretty = TRUE
)
