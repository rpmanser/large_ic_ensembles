#!/bin/sh
#SBATCH -D ./
#SBATCH -J move_clean
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -t 03:00:00
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=1

# ============================================================================================
# sub_move_and_clean.bash
#
# Clean wrf directories after files have been reduced and zipped.
#
# Parameters
# ----------
# $1 = param : parameter file containing WRF settings and paths
# $2 = exp : ensemble experiment name
# $3 = init_start : first initialization date
# $4 = init_end : last initialization date
# ============================================================================================

param=$1
exp=$2
init_start=$3
init_end=$4

source $param

init=$init_start
while [[ "$init" -le "$init_end" ]]; do

  for mem in `seq 1 42`; do
    ${dir_base}/run_ensemble/util/move_and_clean.bash $param $exp $init $mem
  done

  date=`python ${dir_base}/modify_date.py $init 12`
done
