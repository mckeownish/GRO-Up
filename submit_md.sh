#!/bin/bash
#SBATCH --job-name=md_sim
#SBATCH --partition=res-gpu-small
#SBATCH --qos=xsnc46-qos
#SBATCH --gres=gpu:hopper:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=20G
#SBATCH --time=5-00:00:00
#SBATCH --output=slurm_logs/%x_%j.out
#SBATCH --error=slurm_logs/%x_%j.err

# Create logs directory if it doesn't exist
mkdir -p slurm_logs

# Check if PDB file is provided
if [ -z "$PDBFILE" ]; then
    echo "Error: PDBFILE environment variable not set"
    exit 1
fi

# Run the actual simulation script
bash scripts/run_md.sh "$PDBFILE"