#!/bin/bash

# Request resources:
#SBATCH -c 2          # number of CPU cores, one per thread, up to 128
#SBATCH --mem=1G      # memory required, up to 250G on standard nodes
#SBATCH --time=1:0:0  # time limit for job (format:  days-hours:minutes:seconds)
#SBATCH --gres=tmp:1G # temporary disk space required on the compute node ($TMPDIR), 
#                       up to 400G

# Run in the 'shared' queue (job may share node with other jobs)
#SBATCH -p shared

module load gromacs/2023.4             

# Define working directory
WORKDIR="/your/path/to/sim_directory"  # dump the topol.top, npt.gro in here
cd $WORKDIR


# Simulation file definitions
INITIAL_STRUCTURE="npt.gro"
TOPOLOGY_FILE="topol.top"
MDP_FILE="md.mdp"
BASENAME="my_awesome_protein"

# Output files
TPR_OUTPUT="${BASENAME}.tpr"
CHECKPOINT_FILE="${BASENAME}.cpt"


if [ -f "$CHECKPOINT_FILE" ]; then
    # Resume from checkpoint
    SIM_CMD="$gmx mdrun -deffnm $BASENAME -cpi $CHECKPOINT_FILE"
else
    # Start new simulation and prepare the system
    $gmx grompp -f $MDP_FILE -c $INITIAL_STRUCTURE -p $TOPOLOGY_FILE -o $TPR_OUTPUT -maxwarn 1
    SIM_CMD="$gmx mdrun -deffnm $BASENAME -s $TPR_OUTPUT"
fi

# Execute the command
echo "Running command: $SIM_CMD"
$SIM

echo "Simulation complete."
