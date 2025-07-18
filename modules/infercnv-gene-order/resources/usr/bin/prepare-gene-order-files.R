#!/usr/bin/env Rscript

# This script prepares and exports gene order files for use with inferCNV:
# - infercnv-gene-order_chr_<genome reference build>_<ensembl version>.txt: Gene order file with gene positions across chromosomes 1-22,X,Y
# - infercnv-gene-order_arms_<genome reference build>_<ensembl version>.txt: Gene order file with gene positions across chromosome arms 1-22,X,Y
# The genome reference build and ensembl version information is determined from the input GTF file name.

# This script was adapted from the following:

# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/infercnv-consensus-cell-type/scripts/00-make-gene-order-file.R
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/cell-type-wilms-tumor-06/scripts/06a_build-geneposition.R

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--gtf_file"),
    type = "character",
    default = "",
    help = "Path to input GTF file. The file name should be Ensembl formatted with both build and Ensembl version indicators, e.g., Homo_sapiens.GRCh38.104.gtf.gz "
  ),
  make_option(
    opt_str = c("--cytoband_file"),
    type = "character",
    default = "",
    help = "Path to input cytoband file"
  )
)

# Parse options ----------------------
opts <- parse_args(OptionParser(option_list = option_list))
stopifnot(
  "gtf_file does not exist" = file.exists(opts$gtf_file),
  "cytoband_file does not exist" = file.exists(opts$cytoband_file)
)

# Extract reference and version from GTF file
matches <- stringr::str_match(opts$gtf_file, "\\.(GRCh\\d+)\\.(\\d+)\\.gtf(\\.gz)?$")
stopifnot(
  "Could not extract genome build and ensembl version from GTF file name" = !is.na(matches[1])
)
genome_build <- matches[2]
ensembl_release <- matches[3]

# Define output file names
gene_order_file <- glue::glue("infercnv-gene-order_chr_{genome_build}_{ensembl_release}.txt")
arms_gene_order_file <- glue::glue("infercnv-gene-order_arms_{genome_build}_{ensembl_release}.txt")

# Define factor orders for chromosome arms
chrom_levels <- paste0("chr", c(1:22, "X", "Y"))
chrom_arm_levels <- paste0("chr", rep(c(1:22, "X", "Y"), each = 2), c("p", "q"))

# Prepare and export chromosome gene order file ------------------------------

# read in gtf file
gtf <- rtracklayer::import(opts$gtf_file, feature.type = "gene")

# prepare gene order data frame
gene_order_df <- gtf |>
  as.data.frame() |>
  # rename to support joining in next section of script
  dplyr::select(gene_id, chrom = seqnames, gene_start = start, gene_end = end) |>
  dplyr::mutate(chrom = glue::glue("chr{chrom}")) |>
  # keep only chrs of interest
  dplyr::filter(chrom %in% chrom_levels) |>
  # arrange
  dplyr::mutate(chrom = factor(chrom, levels = chrom_levels)) |>
  dplyr::arrange(chrom, gene_start)

# export chromosome gene order file without a header
readr::write_tsv(
  gene_order_df,
  gene_order_file,
  col_names = FALSE
)


# Prepare and export chromosome arm gene order file ------------------------------

# Load cytoBand file into R and assign column names
cytoBand <- readr::read_tsv(
  opts$cytoband_file,
  col_names = c("chrom", "chrom_arm_start", "chrom_arm_end", "band", "stain")
)

# Add a column for the chromosome arm (p or q) and calculate arm positions
chromosome_arms_df <- cytoBand |>
  dplyr::mutate(arm = substr(band, 1, 1)) |>
  # remove NA arms, which are from non-standard chromosomes
  tidyr::drop_na(arm) |>
  dplyr::group_by(chrom, arm) |>
  dplyr::summarize(
    chrom_arm_start = min(chrom_arm_start),
    chrom_arm_end = max(chrom_arm_end),
    .groups = "drop"
  )

arms_gene_order_df <- gene_order_df |>
  # combine gene coordinates with chromosome arm coordinates
  dplyr::left_join(
    chromosome_arms_df,
    by = "chrom",
    relationship = "many-to-many"
  ) |>
  # keep only rows where gene is actually on the chromosome arm
  dplyr::filter(
    gene_start >= chrom_arm_start,
    gene_end <= chrom_arm_end
  ) |>
  # create chrom_arm column as identifier to use instead of chrom
  dplyr::mutate(chrom_arm = glue::glue("{chrom}{arm}")) |>
  # ensure we've kept only chrs of interest
  dplyr::filter(chrom_arm %in% chrom_arm_levels) |>
  # arrange
  dplyr::mutate(chrom_arm = factor(chrom_arm, levels = chrom_arm_levels)) |>
  dplyr::arrange(chrom_arm, gene_start) |>
  # select relevant columns for infercnv
  dplyr::select(gene_id, chrom_arm, gene_start, gene_end)


# export arm gene order file without a header
readr::write_tsv(
  arms_gene_order_df,
  arms_gene_order_file,
  col_names = FALSE
)
