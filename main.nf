#!/usr/bin/env nextflow

// **** Included processes from modules ****
include { example } from './modules/example'

// **** Parameter checks ****
param_error = false

if(param_error){
  System.exit(1)
}

// **** Main workflow ****
workflow {
  example()
}
