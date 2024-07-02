#!/bin/bash

# Specify the SLURM partition to use
#SBATCH --partition=general

# Specify the SLURM account to use
#SBATCH --account=add-your-account

# Specify the number of tasks to use (based on the memory size)
#SBATCH --ntasks=2

# Specify the job array range (1 to 10, change to larger number if more cores needed)
#SBATCH --array=1-10

# Specify the output file for the job logs
#SBATCH --output=TIF_T18TXM.out

# Specify when to send email notifications (ALL events: begin, end, fail, etc.)
#SBATCH --mail-type=ALL

# Specify the email address for notifications
#SBATCH --mail-user=add-your-email-address

# Print the name of the node the job is running on
echo $SLURMD_NODENAME

# Change directory to the specified path
cd add-your-TIF-directory

# Load the MATLAB module
module load matlab

# Run MATLAB in no JVM, no display, no splash, and single computation thread mode
# Execute the batchTIF function with specified parameters
matlab -nojvm -nodisplay -nosplash -singleCompThread -r "batchTIF('task',$SLURM_ARRAY_TASK_ID, 'ntasks',$SLURM_ARRAY_TASK_MAX, 'ARDTiles','18TXM','hide_date','2021-06-16','analysis_scale','30to10');exit"
