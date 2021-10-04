#!/bin/bash

###############################################################################
# calc_enkf_mean.sh
#
# Calculate the mean of the TTU WRF EnKF ensemble experiment
#
# Parameters:
#   $1 = (param) path to parameter file containing paths and WRF info
#   $2 = (date_init) forecast initialization date (YYYYMMDDHH)
#   $3 = (delete_ics) if "true", delete the initial conditions for each member
#        after calculating the mean
#
# Author: R. P. Manser
# Created: 06/05/19
###############################################################################

module load intel
module load nco/4.7.3

param=$1
date_init=$2
delete_ics=${3:-"false"}
source $param

nco=/home/rmanser/software/miniconda3/envs/nco/bin

dir_mean=${dir_scratch}/recenter/${date_init}/enkf_mean
mkdir -p $dir_mean

if [ $date_init -le $date_research ]; then
  dir_enkf=${dir_enkf_research}/${date_init}
elif [ $date_init -le $date_work ]; then
  dir_enkf=$dir_enkf_work/${date_init}
elif [ $date_init -le $date_scratch ]; then
  dir_enkf=$dir_enkf_scratch/${date_init}
fi

cd ${dir_mean}

echo "Copying EnKF ICs to ${dir_mean}..."
for mem in `seq 1 42`; do
  rsync --progress -iropg ${dir_enkf}/mem${mem}/wrfinput_d0* ${dir_mean}

  if [ -e "${dir_mean}/wrfinput_d01.gz" ]; then
    unpigz ${dir_mean}/wrfinput_d01.gz
  fi
  if [ -e "${dir_mean}/wrfinput_d02.gz" ]; then
    unpigz ${dir_mean}/wrfinput_d02.gz
  fi
  mv ${dir_mean}/wrfinput_d01 ${dir_mean}/wrfinput_d01_mem${mem}
  mv ${dir_mean}/wrfinput_d02 ${dir_mean}/wrfinput_d02_mem${mem}
done

${nco}/nces -O ${dir_mean}/wrfinput_d01_mem* ${dir_mean}/wrfinput_d01_mean
${nco}/nces -O ${dir_mean}/wrfinput_d02_mem* ${dir_mean}/wrfinput_d02_mean

if [ "$delete_ics" == "true" ]; then
  rm ${dir_mean}/wrfinput_d0?_mem*
fi
