This module creates and exports gene order files for use with `inferCNV`.

This module exports two versions of the gene order file:

- `inferCNV-gene-order.txt`: This file shows genes ordered by chromosome
- `inferCNV-gene-order-chrarms.txt`: This file shows genes ordered by chromosome arms, e.g. `chr1p` and `chr1q` are separately denoted

The module script is derived from the following scripts in the [OpenScPCA-analysis](https://github.com/AlexsLemonade/OpenScPCA-analysis) repository:

- [`infercnv-consensus-cell-type/scripts/00-make-gene-order-file.R`](https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/infercnv-consensus-cell-type/scripts/00-make-gene-order-file.R)
- [`cell-type-wilms-tumor-06/scripts/06a_build-geneposition.R`](https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/13fd4ac32714c1f6cb7c88cb037a281d4dfd044b/analyses/cell-type-wilms-tumor-06/scripts/06a_build-geneposition.R)
