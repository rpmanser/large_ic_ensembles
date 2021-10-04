#!/bin/sh
#SBATCH -D ./
#SBATCH -J zip_ens
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=3
#SBATCH -t 03:00:00
#SBATCH -a 1-42%4

# ============================================================================================
# sub_zip_ens.bash
#
# Zip or unzip all forecast files for a single WRF ensemble initialization
#
# Parameters
# ----------
# $1 = param : parameter file containing WRF settings and paths
# $2 = exp : ensemble experiment name
# $3 = init : forecast initialization date
# $4 = zip : toggle zip or unzip with possible values of 'zip' and 'unzip'
# $5 = clean (optional) : clean up intermediate files and directories. Can be 'true' or
#   'false'. Default is 'false'.
# ============================================================================================

param=$1
exp=$2
init=$3
zip=$4
clean=${5:-false}

source $param

mem=$SLURM_ARRAY_TASK_ID
dir_scripts=${dir_base}/run_ensemble/util

if [[ "${zip}" == "zip" ]]; then
  script=zip_ens.bash
elif [[ "${zip}" == "unzip" ]]; then
  script=unzip_ens.bash
else
  echo "Invalid value '"${zip}"' for argument zip"
  exit 1
fi

for domain in 1 2; do
  for fhour in `seq 0 48`; do
    ${dir_scripts}/${script} $param $exp $init $fhour $domain $mem
  done
done

if [[ "$clean" == "true" ]]; then
  ${dir_scripts}/move_and_clean.bash $param $exp $init $mem
fi
