#!/usr/bin/env Rscript
#
# This script trains a SingleR model from a given NBAtlas object
# The script restricts genes in the model based on the intersection
# between NBAtlas gene symbols and gene symbols in the GTF, which was used to add
# gene symbols to SCE objects: https://github.com/AlexsLemonade/scpca-nf/blob/8a85702f7c3e616d1d73335d4139d3c72fabfd4e/bin/generate_unfiltered_sce.R#L181
#
# This script was adapted from:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/7c0acea43b6cfc26da75a3a1dbd3558a0d9229ed/analyses/cell-type-neuroblastoma-04/scripts/01_train-singler-model.R

suppressWarnings({
  suppressPackageStartupMessages({
    library(optparse)
    library(SingleCellExperiment)
  })
})


option_list <- list(
  make_option(
    opt_str = c("--nbatlas_sce"),
    type = "character",
    default = "~/ALSF/open-scpca/OpenScPCA-analysis/analyses/cell-type-neuroblastoma-04/references/NBAtlas_sce.rds",
    help = "Path to an NBAtlas object in SCE format"
  ),
  make_option(
    opt_str = c("--gtf_file"),
    type = "character",
    default = "~/Desktop/Homo_sapiens.GRCh38.104.gtf.gz",
    help = "Path to GTF file for determining genes to restrict to"
  ),
  make_option(
    opt_str = c("--singler_model_file"),
    type = "character",
    default = "model.rds",
    help = "Path to RDS file to save trained SingleR model"
  ),
  make_option(
    opt_str = c("--threads"),
    type = "integer",
    default = 4,
    help = "Number of threads for SingleR to use"
  ),
  make_option(
    opt_str = c("--seed"),
    type = "integer",
    default = 2025,
    help = "Random seed"
  )
)

# Parse options and check arguments
opts <- parse_args(OptionParser(option_list = option_list))
stopifnot(
  "nbatlas_sce does not exist" = file.exists(opts$nbatlas_sce),
  "gtf_file does not exist" = file.exists(opts$gtf_file)
)
set.seed(opts$seed)

if (opts$threads == 1) {
  bp_param <- BiocParallel::SerialParam()
} else {
  bp_param <- BiocParallel::MulticoreParam(opts$threads)
}

# Read atlas
nbatlas_sce <- readRDS(opts$nbatlas_sce)

# Read gtf; only genes are needed
gtf <- rtracklayer::import(opts$gtf_file, feature.type = "gene")

# Get all gene symbols present in ScPCA objects
# Source: https://github.com/AlexsLemonade/scpcaTools/blob/f56de55215e95eb6aac1db509e27081adaf5c35a/R/add_gene_symbols.R#L27
scpca_gene_symbols <- gtf |>
  as.data.frame() |>
  dplyr::select(gene_id, gene_name) |>
  tidyr::drop_na(gene_name) |>
  dplyr::distinct() |>
  dplyr::pull(gene_name)

# Define restrict vector for model training as intersection of ScPCA
# and NBAtlas gene symbols
restrict_genes <- intersect(
  scpca_gene_symbols,
  rownames(nbatlas_sce)
)

# Create and export an aggregated version of the reference
nbatlas_trained <- SingleR::trainSingleR(
  ref = nbatlas_sce,
  labels = nbatlas_sce$Cell_type_wImmuneZoomAnnot,
  de.method = "wilcox",
  restrict = restrict_genes,
  aggr.ref = TRUE,
  BPPARAM = bp_param
)
readr::write_rds(nbatlas_trained, opts$singler_model_file)
