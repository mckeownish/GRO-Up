#!/bin/bash

# Define GROMACS executable
gmxc="/usr/local/gromacs/bin/gmx"

# Loop over PDB files in the pdbs directory
for pdbfile in ../pdbs/*.pdb; do
    basename=$(basename $pdbfile .pdb)
    # Create directory for each protein
    mkdir -p ../results/$basename
    cd ../results/$basename

    # Copy CHARMM36m force field to the current directory
    cp -r /path/to/charmm36m.ff ./

    echo -e "\n--- * --- GROMACS format and create topology --- * ---\n"

    # Convert PDB to GROMACS format and create topology
    echo -e "1\n1" | $gmxc pdb2gmx -f ../../pdbs/$basename.pdb -o processed.gro -p topol.top -ignh -water tip3p

    echo -e "\n--- * --- * --- Solvate + box --- * --- * ---\n"

    # Define the box and solvate
    $gmxc editconf -f processed.gro -o boxed.gro -c -d 1.0 -bt dodecahedron
    $gmxc solvate -cp boxed.gro -cs spc216.gro -o solvated.gro -p topol.top

    echo -e "\n--- * --- * --- Add Ions --- * --- * ---\n"

    # Add ions
    $gmxc grompp -f ../../mdp_files/ions.mdp -c solvated.gro -p topol.top -o ions.tpr
    echo 13 | $gmxc genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral -conc 0.15

    echo -e "\n--- * --- * --- Energy Minimisation --- * --- * ---\n"

    # Energy minimization
    $gmxc grompp -f ../../mdp_files/minim.mdp -c solv_ions.gro -p topol.top -o em.tpr
    $gmxc mdrun -v -deffnm em -nb gpu

    echo -e "\n--- * --- * --- Equilibrate --- * --- * ---\n"

    echo -e "\n >> NVT\n"
    $gmxc grompp -f ../../mdp_files/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
    $gmxc mdrun -deffnm nvt -nb gpu -v

    echo -e "\n >> NPT\n"
    $gmxc grompp -f ../../mdp_files/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
    $gmxc mdrun -deffnm npt -nb gpu -v

    echo -e "\n--- * --- * --- Production MD --- * --- * ---\n"

    # Set up and run production MD
    $gmxc grompp -f ../../mdp_files/md.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr
    $gmxc mdrun -deffnm md -nb gpu -v

    echo "Simulation complete for $basename."
    cd ../../scripts/
done