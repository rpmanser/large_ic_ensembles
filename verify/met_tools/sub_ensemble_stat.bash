#!/bin/sh
#SBATCH -D ./
#SBATCH -J ens_stat
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH -t 06:00:00
#SBATCH -a 1-1:1

# ============================================================================================
# sub_ensemble_stat.bash
#
# Run the ensemble_stat tool from the Model Evaluation Tools over all dates
# for a single forecast field and level.
#
# Parameters
# ----------
#   $1 = param : parameters to include in configuration file for ensemble_stat (including
#     names of observation and forecast variables and levels)
#   $2 = experiment : ensemble experiment name
#   $3 = domain : WRF domain number to verify
# ============================================================================================

param=$1
source $param
experiment=$2
domain=$3

DATE_BEGIN=2016042700

let hour='SLURM_ARRAY_TASK_ID * 12 - 12'
date_init=`python ${dir_base}/modify_date.py $DATE_BEGIN $hour`

if [ "$fcst_lvl" == "Surface" ] ; then
  dt=6
else
  dt=12
fi

# fhours=`seq 0 $dt 48`
fhours=`seq 12 $dt 12`

echo '************************************************************************'
echo 'Running METV8.0 ensemble_stat tool'
echo '************************************************************************'
echo 'Initialization date: '$date_init
echo 'Verifying WRF forecast field: '$fcst_key
echo 'Verifying WRF forecast level: '$fcst_lvl
echo 'Verifying WRF forecast domain: '$domain
echo 'Observation field used for verification: '$obs_key
echo 'Observation level used for verification: '$obs_lvl

for fh in $fhours; do
  echo
  echo 'Running ensemble_stat for initialization date '$date_init' and forecast hour '$fh
  ${dir_scripts}/ensemble_stat.bash $param $date_init $fh $domain $experiment
done
