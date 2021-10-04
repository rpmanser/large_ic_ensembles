#!/bin/sh
#SBATCH -D ./
#SBATCH -J wrf_member
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=36
#SBATCH -t 24:00:00

# ============================================================================================
# sub_wrf_member.bash
#
# Submit a single WRF ensemble member forecast to the queue.
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF info
#   $2 = init : forecast intialization date (YYYYMMDDHH)
#   $3 = exp : ensemble experiment name
#   $4 = mem : ensemble member number
#
# ============================================================================================

param=$1
init=$2
exp=$3
mem=$4

source $param

${dir_base}/run_ensemble/run_wrf_member.bash $param $init $exp $mem
