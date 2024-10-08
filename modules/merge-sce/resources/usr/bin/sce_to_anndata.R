#!/usr/bin/env Rscript

# This script takes a SingleCellExperiment stored in a .rds file and converts the main experiment
# (usually RNA) to an AnnData object saved as an hdf5 file

# The AnnData object being exported by this script is formatted to fit CZI schema: 3.0.0

# import libraries
suppressPackageStartupMessages({
  library(optparse)
  library(SingleCellExperiment)
})

# set up arguments
option_list <- list(
  make_option(
    opt_str = c("-i", "--input_sce_file"),
    type = "character",
    help = "path to rds file with input sce object to be converted"
  ),
  make_option(
    opt_str = c("--output_rna_h5"),
    type = "character",
    help = "path to output hdf5 file to store RNA counts as AnnData object. Must end in .hdf5, .h5ad, or .h5"
  ),
  make_option(
    opt_str = c("--output_pca_tsv"),
    default = NULL,
    type = "character",
    help = "path to output a table of variance explained by each principal component. Must end in .tsv"
  ),
  make_option(
    opt_str = c("--feature_name"),
    type = "character",
    help = "Feature type. Must match the altExp name, if present."
  ),
  make_option(
    opt_str = c("--output_feature_h5"),
    type = "character",
    help = "path to output hdf5 file to store feature counts as AnnData object.
    Only used if the input SCE contains an altExp. Must end in .hdf5, .h5, or .h5ad"
  ),
  make_option(
    opt_str = c("--compress_output"),
    action = "store_true",
    default = FALSE,
    help = "Compress the H5AD file containing the AnnData object"
  ),
  make_option(
    opt_str = c("--is_merged"),
    action = "store_true",
    default = FALSE,
    help = "Whether the input SCE file contains a merged object"
  )
)

opt <- parse_args(OptionParser(option_list = option_list))

# Set up -----------------------------------------------------------------------

# check that filtered SCE file exists
if (!file.exists(opt$input_sce_file)) {
  stop(glue::glue("{opt$input_sce_file} does not exist."))
}

# check that output file is h5
if (!(stringr::str_ends(opt$output_rna_h5, ".hdf5|.h5|.h5ad"))) {
  stop("output rna file name must end in .hdf5, .h5, or .h5ad")
}

# check that the pca file is a tsv
if (!is.null(opt$output_pca_tsv) && !stringr::str_ends(opt$output_pca_tsv, ".tsv")) {
  stop("output pca file name must end in .tsv")
}

# Merged object function  ------------------------------------------------------

# this function updates merged object formatting for anndata export
format_merged_sce <- function(sce) {
  # paste X to any present reduced dim names
  reducedDimNames(sce) <- glue::glue("X_{tolower(reducedDimNames(sce))}")
  return(sce)
}

# CZI compliance function ------------------------------------------------------

# this function applies any necessary reformatting or changes needed to make
# sure that the sce that is getting converted to AnnData is compliant with
# CZI 3.0.0 requirements: https://github.com/chanzuckerberg/single-cell-curation/blob/b641130fe53b8163e50c39af09ee3fcaa14c5ea7/schema/3.0.0/schema.md
format_czi <- function(sce) {
  # add schema version
  metadata(sce)$schema_version <- "3.0.0"

  # add library_id as an sce colData column
  # need this column to join in the sample metadata with the colData
  if (!("library_id" %in% colnames(colData(sce)))) {
    sce$library_id <- metadata(sce)$library_id
  }

  # only move sample metadata if not a multiplexed library
  if (!("cellhash" %in% altExpNames(sce))) {
    # add sample metadata to colData sce
    sce <- scpcaTools::metadata_to_coldata(
      sce,
      join_columns = "library_id"
    )
  }

  # modify colData to be AnnData and CZI compliant
  coldata_df <- colData(sce) |>
    as.data.frame() |>
    dplyr::mutate(
      # create columns for assay and suspension ontology terms
      assay_ontology_term_id = metadata(sce)$assay_ontology_term_id,
      suspension_type = metadata(sce)$seq_unit,
      # add is_primary_data column; only needed for anndata objects
      is_primary_data = FALSE
    )

  # add colData back to sce object
  colData(sce) <- DataFrame(
    coldata_df,
    row.names = rownames(colData(sce))
  )

  # remove sample metadata from sce metadata, otherwise conflicts with converting object
  metadata(sce) <- metadata(sce)[names(metadata(sce)) != "sample_metadata"]

  # modify rowData
  # we don't do any gene filtering between normalized and raw counts matrix
  # so everything gets set to false
  rowData(sce)$feature_is_filtered <- FALSE

  # paste X to any present reduced dim names, converting to lower case
  reducedDimNames(sce) <- glue::glue("X_{tolower(reducedDimNames(sce))}")

  return(sce)
}

# MainExp to AnnData -----------------------------------------------------------

# read in sce
sce <- readr::read_rds(opt$input_sce_file)
message("sce read")

# if not enough cells to convert, quit and don't do anything
if (ncol(sce) < 2) {
  quit(save = "no")
}

# grab sample metadata
# we need this if we have any feature data that we need to add it o
sample_metadata <- metadata(sce)$sample_metadata

# make main sce czi compliant for single objects, or format merged objects
if (opt$is_merged) {
  sce <- format_merged_sce(sce)
} else {
  sce <- format_czi(sce)
}

message("Formatting done")



# export sce as anndata object
# this function will also remove any R-specific object types from the SCE metadata
#   before converting to AnnData
scpcaTools::sce_to_anndata(
  sce,
  anndata_file = opt$output_rna_h5,
  compression = ifelse(opt$compress_output, "gzip", "none")
)

# Get PCA metadata for AnnData
if (!is.null(opt$output_pca_tsv) && "X_pca" %in% reducedDimNames(sce)) {
  pca_meta_df <- data.frame(
    PC = 1:ncol(reducedDims(sce)$X_pca),
    variance = attr(reducedDims(sce)$X_pca, "varExplained"),
    variance_ratio = attr(reducedDims(sce)$X_pca, "percentVar") / 100
  )

  # write pca to tsv
  readr::write_tsv(pca_meta_df, opt$output_pca_tsv)
}

message("Exported RNA")

# AltExp to AnnData -----------------------------------------------------------
# end if there is no altExp data or no requested feature
if (is.null(opt$feature_name) || length(altExpNames(sce)) == 0) {
  if (!is.null(opt$feature_name)) {
    warning("No altExp data to convert.")
  }
  quit(save = "no")
}
# check if feature name is in altExp
if (!(opt$feature_name %in% altExpNames(sce))) {
  warning("feature_name should match name of an altExp in provided SCE object.
             The altExp will not be converted.")
  quit(save = "no")
}

# if the feature name is cell hash, skip conversion
if (opt$feature_name == "cellhash") {
  warning("Conversion of altExp data from multiplexed data is not supported.
             The altExp will not be converted.")
  quit(save = "no")
}

# check for output file
if (!(stringr::str_ends(opt$output_feature_h5, ".h5ad|.hdf5|.h5"))) {
  stop("output feature file name must end in .h5ad, .hdf5, or .h5")
}

# extract altExp
alt_sce <- altExp(sce, opt$feature_name)

# only convert altExp with > 1 rows
if (nrow(alt_sce) <= 1) {
  warning(
    glue::glue("
      Only 1 row found in altExp named: {opt$feature_name}.
      This altExp will not be converted to an AnnData object.
    ")
  )
  quit(save = "no")
}

# add sample metadata from main sce to alt sce metadata
metadata(alt_sce)$sample_metadata <- sample_metadata

# make sce czi compliant
alt_sce <- format_czi(alt_sce)
message("alt formatted")

# export altExp sce as anndata object
scpcaTools::sce_to_anndata(
  alt_sce,
  anndata_file = opt$output_feature_h5
)
