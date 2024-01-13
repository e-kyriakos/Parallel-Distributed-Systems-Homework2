# Parallel-Distributed-Systems-Homework-2
This is the Parallel & Distibuted Computer Systems Homework 2: Distributed k-select.

The following Julia script executed a distributed threaded k select of a random array with variable size and given k statistical value.

The script should run on the Aristotelis campus HPC with the appropriate configuration of MPI and Julia scripts: More info can be seen [here](https://juliaparallel.org/MPI.jl/stable/configuration/)

For the correct setup of the HPC follow the instructions found [here](https://hpc.it.auth.gr/)

## Execution 
After the appropriate configurations the create a simillar bash script:


  #!/bin/bash
  
  #SBATCH --partition=rome
  #SBATCH --job-name=Julia-MPI
  #SBATCH --ntasks-per-node=32
  #SBATCH --nodes=2
  #SBATCH --time=10:00
  #SBATCH --mem-per-cpu=2000
  #SBATCH --output=timeN_%j.stdout
  
  module load gcc/10.2.0 julia openmpi
  
  srun -n 2 julia mpi_parallel.jl 10

Preferably a simple Julia execution is of the form: 'mpiexec -n nproc julia mpi_parallel.jl k'

## Execution resuls

The following results are mean times of the configuration found in the above example:
| N  | k | Time (s) |
| --------------- | --------------- | --------------- |
| 10000    | 1000    | 2.54    |
| 100000    | 1000    | 4.69   |
| 100000    | 10    |  4.62    |
