#!/usr/bin/env python3

# Script to perform label transfer using scANVI/scArches a given trained scANVI reference
# This script exports a TSV with cell type labels and associated posterior probabilities
# This script was adapted from:
# https://github.com/AlexsLemonade/OpenScPCA-analysis/blob/82547028b5a9555d8cee40f6c1883015c990cc4f/analyses/cell-type-neuroblastoma-04/scripts/03c_run-scanvi-label-transfer.py

import argparse
import sys
from pathlib import Path

import anndata
from scipy.sparse import csr_matrix
import scvi
import torch

# Define constants
BATCH_KEY = "Sample"  # corresponds to the ScPCA `library_id` (not `sample_id`)
COVARIATE_KEYS = [
    "Assay",
    "Platform",
]
CELL_ID_KEY = "cell_id"
SCANVI_PREDICTIONS_KEY = "scanvi_prediction"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Annotate SCPCP000004 using scANVI/scArches label transfer with the NBAtlas reference.",
    )
    parser.add_argument(
        "--query_file",
        type=Path,
        required=True,
        help="Path to the input AnnData file which has been prepared with prepare-scanvi-query.R",
    )
    parser.add_argument(
        "--reference_scanvi_model_dir",
        type=Path,
        required=True,
        help="Path to the load the scANVI/scArches model trained on NBAtlas",
    )
    parser.add_argument(
        "--predictions_tsv",
        type=Path,
        required=True,
        help="Path to the save TSV file of query scANVI/scArches results."
        " This includes predictions and associated posterior probabilities.",
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

    # Check that input files exist
    if not arg.query_file.is_file():
        print(
            f"The provided input query file could not be found at: {arg.query_file}.",
            file=sys.stderr,
        )
        arg_error = True
    if not arg.reference_scanvi_model_dir.is_dir():
        print(
            f"The provided reference scANVI model could not be found at: {arg.reference_scanvi_model_dir}.",
            file=sys.stderr,
        )
        arg_error = True

    # Read and check that query object has expected columns
    query = anndata.read_h5ad(arg.query_file)
    expected_columns = [BATCH_KEY, CELL_ID_KEY] + COVARIATE_KEYS

    if not set(expected_columns).issubset(query.obs.columns):
        print(
            f"The query AnnData object is missing one or more expected columns: {set(expected_columns).difference(query.obs.columns)}.",
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

    # Load the trained scANVI model for label transfer
    scanvi_model = scvi.model.SCANVI.load(arg.reference_scanvi_model_dir)

    # Ensure anndata is using a sparse matrix for faster processing
    query.X = csr_matrix(query.X)

    ################################################
    # Incorporate query data into the scANVI model #
    ################################################

    # Prepare query data for training
    scvi.model.SCANVI.prepare_query_anndata(query, scanvi_model)
    scanvi_query = scvi.model.SCANVI.load_query_data(query, scanvi_model)

    # Train model and get latent dimensions, cell type predictions
    scanvi_query.train(
        # scArches parameters
        plan_kwargs={"weight_decay": 0.0},
        check_val_every_n_epoch=1,
    )
    query.obs[SCANVI_PREDICTIONS_KEY] = scanvi_query.predict()

    ################################################
    ################ Export objects ################
    ################################################

    # prepare the predictions with posterior probabilities for export
    predictions_df = query.obs[expected_columns + [SCANVI_PREDICTIONS_KEY]]
    posterior_df = scanvi_query.predict(soft=True)
    posterior_df.rename(columns=lambda x: f"pp_{x}", inplace=True)
    predictions_df = predictions_df.join(posterior_df)

    # export TSV
    predictions_df.to_csv(arg.predictions_tsv, sep="\t", index=False)


if __name__ == "__main__":
    main()
