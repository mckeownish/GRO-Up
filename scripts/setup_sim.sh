#!/bin/bash

# SLURM Job Configuration

#SBATCH --partition=multi              # Partition name, change as necessary
#SBATCH --job-name="GRO-Up"        # Job name
#SBATCH --output=job.%j.out           # Standard output (stdout)
#SBATCH --error=job.%j.err            # Standard error (stderr)

#SBATCH --ntasks=192                   # Number of tasks (MPI processes)
#SBATCH --cpus-per-task=2              # Number of CPU cores per task
#SBATCH --nodes=3                      # Number of nodes
#SBATCH --time=72:00:00               # Job time limit (HH:MM:SS)
#SBATCH --gres=tmp:100G               # Temporary storage request
#SBATCH --mem=128G                    # Memory request


module load gromacs/2023.4


# Loop over PDB files in the pdbs directory
for pdbfile in ../pdbs/*.pdb; do
    basename=$(basename $pdbfile .pdb)
    # Create directory for each protein
    mkdir -p ../results/$basename
    cd ../results/$basename

    # Copy CHARMM36m force field to the current directory
    cp -r /nobackup/xsnc46/forcefields/charmm36m.ff .

    echo -e "\n--- * --- GROMACS format and create topology --- * ---\n"

    # Convert PDB to GROMACS format and create topology
    echo -e "1\n1" | gmx_mpi pdb2gmx -f ../../pdbs/$basename.pdb -o processed.gro -p topol.top -ignh -water tip3p

    echo -e "\n--- * --- * --- Solvate + box --- * --- * ---\n"

    # Define the box and solvate
    gmx_mpi editconf -f processed.gro -o boxed.gro -c -d 1.0 -bt dodecahedron
    gmx_mpi solvate -cp boxed.gro -cs spc216.gro -o solvated.gro -p topol.top

    echo -e "\n--- * --- * --- Add Ions --- * --- * ---\n"

    # Add ions
    gmx_mpi grompp -f ../../mdp_files/ions.mdp -c solvated.gro -p topol.top -o ions.tpr
    echo 13 | gmx_mpi genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral -conc 0.15

    echo -e "\n--- * --- * --- Energy Minimisation --- * --- * ---\n"

    # Energy minimization
    gmx_mpi grompp -f ../../mdp_files/minim.mdp -c solv_ions.gro -p topol.top -o em.tpr
    mpirun gmx_mpi mdrun -v -deffnm em

    echo -e "\n--- * --- * --- Equilibrate --- * --- * ---\n"

    echo -e "\n >> NVT\n"
    gmx_mpi grompp -f ../../mdp_files/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
    mpirun gmx_mpi mdrun -deffnm nvt -v

    echo -e "\n >> NPT\n"
    gmx_mpi grompp -f ../../mdp_files/npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
    mpirun gmx_mpi mdrun -deffnm npt -v

    echo -e "\n--- * --- * --- Production MD --- * --- * ---\n"

    # Set up and run production MD
    gmx_mpi grompp -f ../../mdp_files/md.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr
    mpirun gmx_mpi mdrun -deffnm md -v 

    echo "Simulation complete for $basename."
    cd ../../scripts/
done