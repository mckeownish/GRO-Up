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

# Load GROMACS
module load gromacs/2023.5

# Create results directory for this protein
mkdir -p results/$basename
cd results/$basename

FORCEFIELD_PATH="../../FFs/amber14sb.ff"

# Copy force field to working directory (if using local force field)
if [ -d "$FORCEFIELD_PATH" ]; then
    echo "Copying force field from $FORCEFIELD_PATH"
    cp -r $FORCEFIELD_PATH .
fi

echo -e "\n=== Processing $basename ===\n"

echo -e "\n--- * --- GROMACS format and create topology --- * ---\n"
# Convert PDB to GROMACS format with AMBER14SB
echo -e "0\n0" | gmx_mpi pdb2gmx -ff amber14sb -f ../../$PDBFILE -o GMX.gro -p topol.top -water tip3p

echo -e "\n--- * --- * --- Create box and center --- * --- * ---\n"
gmx_mpi editconf -f GMX.gro -o boxed.gro -c -d 2.0 -bt dodecahedron
gmx_mpi editconf -f boxed.gro -o centered.gro -c

echo -e "\n--- * --- * --- Solvate --- * --- * ---\n"
gmx_mpi solvate -cp centered.gro -cs spc216.gro -o solvated.gro -p topol.top

echo -e "\n--- * --- * --- Add Ions --- * --- * ---\n"
gmx_mpi grompp -f ../../mdp_files/ions.mdp -c solvated.gro -p topol.top -o ions.tpr
echo 13 | gmx_mpi genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral -conc 0.15

echo -e "\n--- * --- * --- Energy Minimisation --- * --- * ---\n"
gmx_mpi grompp -f ../../mdp_files/minim.mdp -c solv_ions.gro -p topol.top -o em1.tpr
gmx_mpi mdrun -v -deffnm em1 -nb gpu

gmx_mpi grompp -f ../../mdp_files/minim2.mdp -c em1.gro -p topol.top -o em2.tpr
gmx_mpi mdrun -v -deffnm em2 -nb gpu

echo -e "\n--- * --- * --- Equilibrate --- * --- * ---\n"
echo -e "\n >> NVT\n"
gmx_mpi grompp -f ../../mdp_files/nvt.mdp -c em2.gro -r em2.gro -p topol.top -o nvt.tpr
gmx_mpi mdrun -v -deffnm nvt -nb gpu -pme gpu -bonded gpu -update gpu -ntomp $SLURM_CPUS_PER_TASK

echo -e "\n >> NPT\n"
gmx_mpi grompp -f ../../mdp_files/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
gmx_mpi mdrun -v -deffnm npt -nb gpu -pme gpu -bonded gpu -update gpu -ntomp $SLURM_CPUS_PER_TASK

echo -e "\n--- * --- * --- Production MD --- * --- * ---\n"
gmx_mpi grompp -f ../../mdp_files/md.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr
gmx_mpi mdrun -v -deffnm md -nb gpu -pme gpu -bonded gpu -update gpu -ntomp $SLURM_CPUS_PER_TASK

echo -e "\n=== Simulation complete for $basename ===\n"
echo -e "Results saved in: results/$basename"

cd ../..