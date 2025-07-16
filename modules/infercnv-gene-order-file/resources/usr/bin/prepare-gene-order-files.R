#!/usr/bin/env Rscript

# This script prepares and exports gene order files for use with inferCNV with the GRCh38 reference genome, Ensembl 104 annotation:
# - inferCNV-gene-order.txt: Gene order file with gene positions across chromosomes 1-22,X,Y
# - inferCNV-gene-order-chrarms.txt: Gene order file with gene positions across chromosome arms 1-22,X,Y

# This script was adapted from the following:

# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/infercnv-consensus-cell-type/scripts/00-make-gene-order-file.R
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/cell-type-wilms-tumor-06/scripts/06a_build-geneposition.R

library(optparse)

option_list <- list(
  make_option(
    opt_str = c("--gtf_file"),
    type = "character",
    default = "",
    help = "Path to input GTF file"
  ),
  make_option(
    opt_str = c("--cytoband_file"),
    type = "character",
    default = "",
    help = "Path to input cytoband file"
  ),
  make_option(
    opt_str = c("--gene_order_file_name"),
    type = "character",
    default = "inferCNV-gene-order.txt",
    help = "Output file name for the gene order file without chromosome arms."
  ),
  make_option(
    opt_str = c("--arms_gene_order_file_name"),
    type = "character",
    default = "inferCNV-gene-order-chrarms.txt",
    help = "Output file name for the gene order file with chromosome arms."
  )
)

# Parse options
opts <- parse_args(OptionParser(option_list = option_list))
stopifnot(
  "gtf_file does not exist" = file.exists(opts$gtf_file),
  "cytoband_file does not exist" = file.exists(opts$cytoband_file)
)

# Gene order file without chromosome arms ------------------------------

# read in gtf file
gtf <- rtracklayer::import(opts$gtf_file, feature.type = "gene")

# prepare gene order data frame
gene_order_df <- gtf |>
  as.data.frame() |>
  # rename to support joining in next section of script
  dplyr::select(gene_id, chrom = seqnames, gene_start = start, gene_end = end) |>
  dplyr::mutate(chrom = glue::glue("chr{chrom}")) |>
  # only keep chr1 - 22 and chrX and chrY
  dplyr::filter(grepl("^chr([1-9]|1[0-9]|2[0-2]|X|Y)$", chrom))

# export gene order file without a header
readr::write_tsv(
  gene_order_df,
  opts$gene_order_file,
  col_names = FALSE
)


# Gene order file with chromosome arms ------------------------------


# Load cytoBand file into R and assign column names
cytoBand <- readr::read_tsv(opts$cytoband_file, col_names = FALSE)
colnames(cytoBand) <- c("chrom", "chrom_arm_start", "chrom_arm_end", "band", "stain")

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
  # Select only relevant column for infercnv
  dplyr::select(gene_id, chrom_arm, gene_start, gene_end)


# export chromosome-arm gene order file without a header
readr::write_tsv(
  arms_gene_order_df,
  opts$arms_gene_order_file_name,
  col_names = FALSE
)
