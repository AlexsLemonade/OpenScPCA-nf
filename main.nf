#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// **** Included processes from modules ****
// include { example } from './modules/example.nf' // example syntax

// **** Parameter checks ****
param_error = false

if(param_error){
  System.exit(1)
}

// **** Main workflow ****
workflow {

}
