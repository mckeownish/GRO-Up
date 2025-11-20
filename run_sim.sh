#!/bin/bash
# Wrapper to submit MD simulations
# Usage: ./run_sim.sh pdbs/protein.pdb

if [ $# -eq 0 ]; then
    echo "Error: No PDB file provided"
    echo "Usage: ./run_sim.sh pdbs/<protein.pdb>"
    exit 1
fi

PDBFILE=$1

# Check if file exists
if [ ! -f "$PDBFILE" ]; then
    echo "Error: File $PDBFILE not found"
    exit 1
fi

# Get basename for job name
basename=$(basename $PDBFILE .pdb)

# Submit job with PDB file as environment variable
sbatch --job-name=md_$basename --export=ALL,PDBFILE=$PDBFILE submit_md.sh

echo "Submitted MD simulation for $basename"
echo "Check status with: squeue -u $USER"
echo "View logs in: slurm_logs/"