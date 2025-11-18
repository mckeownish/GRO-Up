#!/bin/bash
# AMBER14SB single protein MD simulation script
# Usage: ./run_md.sh protein.pdb

# Check if PDB file is provided
if [ $# -eq 0 ]; then
    echo "Error: No PDB file provided"
    echo "Usage: ./run_md.sh <protein.pdb>"
    exit 1
fi

# Get input PDB file
PDBFILE=$1

# Check if file exists
if [ ! -f "$PDBFILE" ]; then
    echo "Error: File $PDBFILE not found"
    exit 1
fi

# Get basename without extension
basename=$(basename $PDBFILE .pdb)

# Set path to force field (CHANGE THIS to your force field location)
FORCEFIELD_PATH="/path/to/your/amber14sb.ff"

# Load GROMACS
module load gromacs/2023.5

# Create results directory for this protein
mkdir -p ../results/$basename
cd ../results/$basename

# Copy force field to working directory (if using local force field)
if [ -d "$FORCEFIELD_PATH" ]; then
    echo "Copying force field from $FORCEFIELD_PATH"
    cp -r $FORCEFIELD_PATH .
fi

echo -e "\n=== Processing $basename ===\n"

echo -e "\n--- * --- GROMACS format and create topology --- * ---\n"
# Convert PDB to GROMACS format with AMBER14SB
# Automatic terminal selection: 0=charged termini
echo -e "0\n0" | gmx pdb2gmx -ff amber14sb -f ../../$PDBFILE -o GMX.gro -p topol.top -water tip3p

echo -e "\n--- * --- * --- Create box and center --- * --- * ---\n"
# Define the box with 2.0 nm buffer
gmx editconf -f GMX.gro -o boxed.gro -c -d 2.0 -bt dodecahedron
# Center the protein in the box
gmx editconf -f boxed.gro -o centered.gro -c

echo -e "\n--- * --- * --- Solvate --- * --- * ---\n"
# Solvate the system
gmx solvate -cp centered.gro -cs spc216.gro -o solvated.gro -p topol.top

echo -e "\n--- * --- * --- Add Ions --- * --- * ---\n"
# Add ions (group 13 is typically SOL)
gmx grompp -f ../../mdp_files/ions.mdp -c solvated.gro -p topol.top -o ions.tpr
echo 13 | gmx genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral -conc 0.15

echo -e "\n--- * --- * --- Energy Minimisation --- * --- * ---\n"
# Energy minimization - stage 1 (steepest descent)
gmx grompp -f ../../mdp_files/minim.mdp -c solv_ions.gro -p topol.top -o em1.tpr
gmx mdrun -v -deffnm em1 -nb gpu

# Energy minimization - stage 2 (conjugate gradient)
gmx grompp -f ../../mdp_files/minim2.mdp -c em1.gro -p topol.top -o em2.tpr
gmx mdrun -v -deffnm em2 -nb gpu

echo -e "\n--- * --- * --- Equilibrate --- * --- * ---\n"
echo -e "\n >> NVT\n"
# NVT equilibration with GPU-resident mode
gmx grompp -f ../../mdp_files/nvt.mdp -c em2.gro -r em2.gro -p topol.top -o nvt.tpr
gmx mdrun -v -deffnm nvt -nb gpu -pme gpu -bonded gpu -update gpu -ntomp 8

echo -e "\n >> NPT\n"
# NPT equilibration with GPU-resident mode
gmx grompp -f ../../mdp_files/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
gmx mdrun -v -deffnm npt -nb gpu -pme gpu -bonded gpu -update gpu -ntomp 8

echo -e "\n--- * --- * --- Production MD --- * --- * ---\n"
# Set up and run production MD with full GPU offloading
gmx grompp -f ../../mdp_files/md.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr
gmx mdrun -v -deffnm md -nb gpu -pme gpu -bonded gpu -update gpu -ntomp 8

echo -e "\n=== Simulation complete for $basename ===\n"
echo -e "Results saved in: ../results/$basename"
echo -e "Output files:"
echo -e "  - Topology: topol.top"
echo -e "  - Final structure: md.gro"
echo -e "  - Trajectory: md.xtc"
echo -e "  - Energy: md.edr"
echo -e "  - Log: md.log"

# Return to script directory
cd ../../scripts/
