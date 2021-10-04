#!/bin/bash
#SBATCH -D ./
#SBATCH -J wrfpost
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH -a 1-1:1

# ============================================================================================
# sub_wrf_post.bash
#
# Post-process WRF ensemble forecasts. Upper air forecasts are processed every 12 hours,
# surface forecasts every 6 hours, and convective forecasts every hour.
#
# Parameters
# ----------
#   $1 = param : parameter file containing WRF settings and directories
#   $2 = exp : ensemble experiment name
#   $3 = hour_start : first forecast hour to process
#   $4 = hour_end : final forecast hour to process
#   $5 = domain : domain number to process
#   $6 = nmem : number of ensemble members
# ============================================================================================

param=$1
exp=$2
hour_start=$3
hour_end=$4
domain=$5
nmem=${6:-42}

source $param

source activate ens
pyenv=`which python`
pylog="INFO"
export LOG_LEVEL=$pylog

DATE_BEGIN=2016042700
let dt='SLURM_ARRAY_TASK_ID * 12 - 12'
init=`python ${dir_base}/modify_date.py $DATE_BEGIN $dt`

echo "Experiment: $exp"
echo "Initialization $init"
echo "Start hour: $hour_start"
echo "End hour: $hour_end"
echo "Domain: $domain"
echo "Number of ensemble members: $nmem"

# Experiments are scattered across lustre
if [[ "$exp" = "perturb_GFS_fixed" ]] || \
[[ "$exp" = *"exp"* ]] || \
[[ "$exp" = *"scaled"* ]]; then
  directory=/lustre/scratch/rmanser/${exp}/${init}
elif [[ "$exp" = "SE2016" ]]; then

  if [[ $init -gt $date_research ]] && [[ $init -le $date_work ]]; then
    directory=$dir_enkf_work
  else
    directory=$dir_enkf_research
  fi

elif [[ "$exp" == "perturb_GFS" ]]; then
  directory=/lustre/scratch/rmanser/${exp}/${init}
else
  directory=/lustre/research/bancell/rmanser/${exp}/${init}
fi

path_ref=/lustre/work/rmanser/wrfref/wrfoutREFd0${domain}
path_save=/lustre/scratch/rmanser/wrf_post/${exp}/${init}
prefix=wrfout_d0${domain}_red_

mkdir -p $path_save

for fhour in `seq $hour_start $hour_end`; do
  $pyenv /home/rmanser/scripts/wrf_post.py $directory $init $fhour $nmem $domain \
  --path_ref $path_ref --path_save $path_save --prefix $prefix
done
