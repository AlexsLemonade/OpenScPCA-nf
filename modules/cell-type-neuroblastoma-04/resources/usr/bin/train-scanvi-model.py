#!/usr/bin/env python3

# Script to train a scANVI/scArches model from the NBAtlas reference
# This script was adapted from:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/03a_train-scanvi-model.py

import argparse
import sys
from pathlib import Path

import anndata
from scipy.sparse import csr_matrix
import scvi
import torch

# Define constants
BATCH_KEY = "Sample"
COVARIATE_KEYS = [
    "Assay",
    "Platform",
]
CELLTYPE_COLUMN = "Cell_type_wImmuneZoomAnnot"
CELL_ID_KEY = "cell_id"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train a scANVI/scArches model from the NBAtlas reference.",
    )
    parser.add_argument(
        "--reference_file",
        type=Path,
        required=True,
        help="Path to the input NBAtlas reference file",
    )
    parser.add_argument(
        "--reference_scanvi_model_dir",
        type=Path,
        required=True,
        help="Path to directory where the scANVI model trained on the reference object will be saved."
        " This directory will be created at export.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=2025,
        help="Random seed to ensure reproducibility",
    )
    arg = parser.parse_args()

    ################################################
    ########### Input argument checks ##############
    ################################################
    arg_error = False

    # Check that the input file exists
    if not arg.reference_file.is_file():
        print(
            f"The provided input reference file could not be found at: {arg.reference_file}.",
            file=sys.stderr,
        )
        arg_error = True

    # Read and check that the reference object has expected columns
    reference = anndata.read_h5ad(arg.reference_file)
    expected_columns = [BATCH_KEY, CELL_ID_KEY, CELLTYPE_COLUMN] + COVARIATE_KEYS

    if not set(expected_columns).issubset(reference.obs.columns):
        print(
            f"The reference AnnData object is missing one or more expected columns: {set(expected_columns).difference(reference.obs.columns)}.",
            file=sys.stderr,
        )
        arg_error = True

    # Exit if error(s)
    if arg_error:
        sys.exit(1)

    # Set seed for reproducibility
    # torch commands are ignored if GPU not present
    scvi.settings.seed = arg.seed  # inherited by numpy and torch
    torch.cuda.manual_seed(arg.seed)
    torch.cuda.manual_seed_all(arg.seed)

    # Ensure anndata is using a sparse matrix for faster processing
    reference.X = csr_matrix(reference.X)

    ################################################
    ######## SCVI reference model training #########
    ################################################

    scvi.model.SCVI.setup_anndata(
        reference,
        batch_key=BATCH_KEY,
        categorical_covariate_keys=COVARIATE_KEYS,  # control for cell/nucleus and 10x2/3
    )

    scvi_model = scvi.model.SCVI(
        reference,
        # scArches parameters
        # from: https://docs.scvi-tools.org/en/1.3.2/tutorials/notebooks/multimodal/scarches_scvi_tools.html#train-reference
        use_layer_norm="both",
        use_batch_norm="none",
        encode_covariates=True,  # essential for scArches
        dropout_rate=0.2,
        n_layers=2,
    )

    # Train SCVI model; will automatically detect architecture to run on CPU or GPU
    scvi_model.train()

    ################################################
    ####### scANVI reference model training ########
    ################################################

    scanvi_model = scvi.model.SCANVI.from_scvi_model(
        scvi_model,
        unlabeled_category="Unknown",  # will be used to set up query next; labels will start as `Unknown`
        labels_key=CELLTYPE_COLUMN,
    )
    scanvi_model.train()

    ################################################
    ################ Export objects ################
    ################################################

    # Export the NBAtlas-trained scANVI model
    scanvi_model.save(arg.reference_scanvi_model_dir, save_anndata=True, overwrite=True)


if __name__ == "__main__":
    main()
