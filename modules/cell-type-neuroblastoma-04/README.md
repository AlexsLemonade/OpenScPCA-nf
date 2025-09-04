This module assigns cell types to all Neuroblastoma samples in `SCPCP000004`.

The module creates a TSV file with annotations for each library with the following columns:

* `barcodes`: Unique cell barcode
* `neuroblastoma_04_annotation`: Final module cell type annotation
* `neuroblastoma_04_ontology`: CL ontology id associated with the annotation, if available
* `neuroblastoma_04_ontology_label`: CL ontology label associated with the annotation, if available
* `singler_label`: Label predicted by `SingleR`, based on the outputted `pruned.labels` column
* `scanvi_label`: Label predicted by `scANVI/scArches`, where labels with a posterior probability < 0.75 are given as `Unknown`
* `cell_class`: Cell classification, one of "tumor", "normal", or "unknown"

For full information about how annotations are assigned, refer to the [`OpenScPCA-analysis` repository's `cell-type-neuroblastoma-04` module README](https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/main/analyses/cell-type-neuroblastoma-04/README.md).

Scripts are derived from the the `cell-type-neuroblastoma-04` module of the [OpenScPCA-analysis](https://github.com/AlexsLemonade/OpenScPCA-analysis) repository.
Links to specific original scripts and notebooks used in this module:

* `00_convert-nbatlas.R`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/ad3b3c6ac6bcb7154058e4f725250dc56523caa8/analyses/cell-type-neuroblastoma-04/scripts/00_convert-nbatlas.R>
* `01_train-singler-model.R`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/7c0acea43b6cfc26da75a3a1dbd3558a0d9229ed/analyses/cell-type-neuroblastoma-04/scripts/01_train-singler-model.R>
* `02_classify-singler.R`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/02_classify-singler.R>
* `03a_train-scanvi-model.py`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/03a_train-scanvi-model.py>
* `03b_prepare-scanvi-query.R`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/03b_prepare-scanvi-query.R>
* `03c_run-scanvi-label-transfer.py`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/03c_run-scanvi-label-transfer.py>
* `final-annotation.Rmd`: <https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/final-annotation.Rmd>
