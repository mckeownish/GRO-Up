#!/bin/bash

# Load GROMACS
# source /usr/local/gromacs/bin/GMXRC
gmx=gmx

# Configuration and paths
source config.sh

# Loop over PDB files in the pdbs directory
for pdbfile in ../pdbs/*.pdb; do
    basename=$(basename $pdbfile .pdb)

    # Create directory for each protein
    mkdir -p ../results/$basename
    cd ../results/$basename

    echo "\n"
    echo "--- * --- GROMACS format and create topology --- * ---\n"
    echo "\n"

    # Convert PDB to GROMACS format and create topology
    $gmx pdb2gmx -f ../../pdbs/$basename.pdb -o processed.gro -p topol.top -ignh -water $gmxwatermodel -ff $gmxforcefield
    
    echo "\n"
    echo "--- * --- * --- Solvate + box --- * --- * ---\n"
    echo "\n"

    # Define the box and solvate
    $gmx editconf -f processed.gro -o boxed.gro -c -d 1.0 -bt cubic
    $gmx solvate -cp boxed.gro -cs spc216.gro -o solvated.gro -p topol.top

    echo "\n"
    echo "--- * --- * --- Add Ions --- * --- * ---\n"
    echo "\n"

    # Add ions
    $gmx grompp -f ../../mdp_files/ions.mdp -c solvated.gro -p topol.top -o ions.tpr

    # 13 = SOL for genion - change if you dont want that...
    echo 13 | $gmx genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral #-conc 0.15

    echo "\n"
    echo "--- * --- * --- Energy Minimisation --- * --- * ---\n"
    echo "\n"

    # Energy minimization
    $gmx grompp -f ../../mdp_files/minim.mdp -c solv_ions.gro -p topol.top -o em.tpr
    $gmx mdrun -v -deffnm em

    # Equilibration steps: NVT then NPT

    echo "\n"
    echo "--- * --- * --- Equilibrate --- * --- * ---\n"
    echo "\n \n"
    echo " >> NVT"
    echo "\n \n"

    $gmx grompp -f ../../mdp_files/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
    $gmx mdrun -deffnm nvt
    
    echo "\n"
    echo " >> NPT"
    echo "\n \n"

    $gmx grompp -f ../../mdp_files/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
    $gmx mdrun -deffnm npt

    echo "Simulation setup complete for $basename."
    cd ../../scripts/
done
