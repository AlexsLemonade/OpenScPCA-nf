#!/usr/bin/env Rscript
#
# This script prepares the a given SCE object for input to scANVI:
# - unneeded slots are removed to save space/memory
# - rownames are converted to gene symbols
# - the object is subset to the NBAtlas HVGs
# - fields to match NBAtlas covariate encoding are added to the colData
# - the object is exported as an AnnData object
# This script was adapted from:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/03b_prepare-scanvi-query.R

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--sce_file"),
    type = "character",
    default = "",
    help = "Path to the SCE file to prepare"
  ),
  make_option(
    opt_str = c("--nbatlas_hvg_file"),
    type = "character",
    default = "",
    help = "Path to text file with top 2000 HVGs of the NBAtlas object, as gene symbols"
  ),
  make_option(
    opt_str = c("--prepared_anndata_file"),
    type = "character",
    default = "",
    help = "Path to output the updated AnnData file to use as scANVI query input"
  )
)

# Parse options and check arguments
opts <- parse_args(OptionParser(option_list = option_list))

stopifnot(
  "sce_file does not exist" = file.exists(opts$sce_file),
  "nbatlas_hvg_file does not exist" = file.exists(opts$nbatlas_hvg_file)
)

# load the bigger libraries after passing checks
suppressPackageStartupMessages({
  library(SingleCellExperiment)
  library(zellkonverter)
})


# read sce
sce <- readRDS(opts$sce_file)

# remove assays, reducedDims for space
assay(sce, "logcounts") <- NULL
assay(sce, "spliced") <- NULL
reducedDims(sce) <- NULL

# read gene symbols
hv_gene_symbols <- readr::read_lines(opts$nbatlas_hvg_file)

# convert to gene symbols
sce <- rOpenScPCA::sce_to_symbols(sce, reference = "sce")

# subset sce
# note that only 1975 genes are present out of 2000, which is 98-99%
# scanvi warns if there is less than 80% overlap, so this is fine. sources:
# https://github.com/scverse/scvi-tools/blob/70564c397b789943230b900500c557f31905d91b/src/scvi/model/base/_archesmixin.py#L40
# https://github.com/scverse/scvi-tools/blob/70564c397b789943230b900500c557f31905d91b/src/scvi/model/base/_archesmixin.py#L479
intersecting_genes <- intersect(rownames(sce), hv_gene_symbols) # 1975 genes
sce <- sce[intersecting_genes, ]

# update colData to include columns that match NBAtlas naming
colData(sce) <- colData(sce) |>
  as.data.frame() |>
  dplyr::mutate(
    Sample = metadata(sce)$library_id,
    Assay = ifelse(metadata(sce)$seq_unit == "cell", "single-cell", "single-nucleus"),
    Platform = stringr::str_replace(metadata(sce)$tech_version, "v", "_v"),
    cell_id = glue::glue("{metadata(sce)$library_id}-{barcodes}")
  ) |>
  # recode NAs to support anndata conversion
  # source: https://github.com/AlexsLemonade/scpcaTools/blob/d0fe377284aaa1b4b0647374060e5c699b4c3a48/R/sce_to_anndata.R#L78
  dplyr::mutate(
    dplyr::across(dplyr::where(\(x) all(is.na(x))), as.logical)
  ) |>
  DataFrame(row.names = colnames(sce))

# remove metadata to support anndata conversion
metadata(sce) <- list()

# export as an AnnData object
zellkonverter::writeH5AD(
  sce,
  opts$prepared_anndata_file,
  X_name = "counts",
  compression = "gzip"
)
