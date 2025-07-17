This module creates and exports gene order files for use with `inferCNV`.

This module exports two versions of the gene order file:

- `infercnv-gene-order_chr_<genome reference build>_<ensembl version>.txt`: Gene order file with gene positions across chromosomes 1-22,X,Y
- `infercnv-gene-order_arms_<genome reference build>_<ensembl version>.txt`: Gene order file with gene positions across chromosome arms 1-22,X,Y

The genome reference build and ensembl version information is determined from the input GTF file name.

The module script is derived from the following scripts in the [OpenScPCA-analysis](https://github.com/AlexsLemonade/OpenScPCA-analysis) repository:

- [`infercnv-consensus-cell-type/scripts/00-make-gene-order-file.R`](https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/infercnv-consensus-cell-type/scripts/00-make-gene-order-file.R)
- [`cell-type-wilms-tumor-06/scripts/06a_build-geneposition.R`](https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/cell-type-wilms-tumor-06/scripts/06a_build-geneposition.R)
