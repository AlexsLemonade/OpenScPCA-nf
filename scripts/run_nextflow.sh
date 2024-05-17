#/bin/bash
cd /opt/nextflow
/usr/local/bin/nextflow  -C nextflow.config run main.nf -profile batch
