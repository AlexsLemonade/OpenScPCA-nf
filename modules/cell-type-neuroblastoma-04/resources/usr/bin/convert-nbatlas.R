#!/usr/bin/env Rscript
#
# This script exports an SCE and AnnData version of a given NBAtlas Seurat object
# The SCE object retains the raw counts, normalized counts, and cell metadata
# The AnnData object retains only the raw counts for the top 2000 high-variance genes, and cell metadata
#  This allows for a smaller object export and lower memory usage during SCVI/SCANVI training
# In addition, a text file with the top 2000 high-variance genes is exported
#
# During processing, one piece of metadata in the object is further updated:
# The `Platform` value for the Costa2022 Study should be `10x_v3.1` and not `10x_v3`
# See this issue discussion for context:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/pull/1231#discussion_r2226070913
#
# This script was adapted from:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/ad3b3c6ac6bcb7154058e4f725250dc56523caa8/analyses/cell-type-neuroblastoma-04/scripts/00_convert-nbatlas.R

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--nbatlas_file"),
    type = "character",
    default = "",
    help = "Path to Seurat version of an NBAtlas object"
  ),
  make_option(
    opt_str = c("--sce_file"),
    type = "character",
    help = "Path to output RDS file to hold an SCE version of the NBAtlas object."
  ),
  make_option(
    opt_str = c("--anndata_file"),
    type = "character",
    help = "Path to output H5AD file to hold an AnnData version of the NBAtlas object."
  ),
  make_option(
    opt_str = c("--nbatlas_hvg_file"),
    type = "character",
    help = "Path to output text file to save top 2000 HVGs of the NBAtlas object."
  )
)

# Parse options and check arguments
opts <- parse_args(OptionParser(option_list = option_list))

stopifnot(
  "nbatlas_file does not exist" = file.exists(opts$nbatlas_file),
  "sce_file was not provided" = !is.null(opts$sce_file),
  "anndata_file was not provided" = !is.null(opts$anndata_file),
  "nbatlas_hvg_file was not provided" = !is.null(opts$nbatlas_hvg_file)
)

# load the bigger libraries after passing checks
suppressPackageStartupMessages({
  library(Seurat)
  library(SingleCellExperiment)
  library(zellkonverter)
})

# read input file and convert to SCE
nbatlas_seurat <- readRDS(opts$nbatlas_file)
# seurat gives an expected warning here
suppressWarnings({
  nbatlas_sce <- as.SingleCellExperiment(nbatlas_seurat)
})

# remove Seurat file to save space
rm(nbatlas_seurat)
gc()

# Update SCE innards:
# - remove reducedDim for space
# - add `cell_id` columns to colData
# - update Costa2022 Platform to 10X_v3.1

reducedDims(nbatlas_sce) <- NULL
colData(nbatlas_sce) <- colData(nbatlas_sce) |>
  as.data.frame() |>
  dplyr::mutate(
    cell_id = rownames(colData(nbatlas_sce)),
    Platform = ifelse(
      Study == "Costa2022",
      "10X_v3.1",
      Platform
    )
  ) |>
  DataFrame(row.names = rownames(colData(nbatlas_sce)))

# export SCE version of NBAtlas object
readr::write_rds(
  nbatlas_sce,
  opts$sce_file,
  compress = "gz"
)


# Perform some additional processing before AnnData export:
# - subset to top 2000 HVGs (batch-aware); these will also be exported
# - remove logcounts

gene_var <- scran::modelGeneVar(
  nbatlas_sce,
  block = nbatlas_sce$Sample
)
hv_genes <- scran::getTopHVGs(gene_var, n = 2000)

nbatlas_sce <- nbatlas_sce[hv_genes, ]
logcounts(nbatlas_sce) <- NULL

# export the AnnData object
zellkonverter::writeH5AD(
  nbatlas_sce,
  opts$anndata_file,
  X_name = "counts",
  compression = "gzip"
)

# export text file with the HVGs
readr::write_lines(hv_genes, opts$nbatlas_hvg_file)
