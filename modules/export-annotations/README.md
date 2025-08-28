This module exports annotations from cell type modules in a uniform format to a public s3 bucket for use in other applications.
Annotations can be found in `s3://openscpca-celltype-annotations-public-access`.

For each library, a JSON file is exported with the following information:

| | |
| -- | -- |
| `barcodes` | An array of unique cell barcodes |
| `openscpca_celltype_annotation` | An array of cell type annotations assigned in `OpenScPCA-nf` |
| `openscpca_celltype_ontology` | An array of Cell Ontology identifiers associated with the cell type annotation. If no Cell Ontology identifiers are assigned, this will be `NA` |
| `module_name` | Name of the original analysis module used to assign cell type annotations in `OpenScPCA-analysis` |
| `openscpca_nf_version` | Version of `OpenScPCA-nf` |
| `release_date` | Release date of input ScPCA data |
