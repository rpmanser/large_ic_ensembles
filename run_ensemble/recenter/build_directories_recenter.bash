#!/bin/bash

# ============================================================================================
# build_directories.bash
#
# Create a directory structure for an ensemble with EnKF perturbations
# re-centered around GFS ICs.
#
# Parameters
# ----------
#   $1 = param : parameter file containing paths and WRF info
#   $2 = date_init : forecast initialization date (i.e., name of parent directory)
#   $3 = num_mem : number of ensemble members
# ============================================================================================

param=$1
date_init=$2
num_mem=$3
source $param

dir_exp=${dir_scratch}/recenter

mkdir -p ${dir_exp}/${date_init}
cd ${dir_exp}/${date_init}

for mem in `seq 1 ${num_mem}` ; do

  if [ ! -d "${dir_exp}/${date_init}/mem${mem}/wrf" ] ; then
    mkdir -p ${dir_exp}/${date_init}/mem${mem}/wrf
    ln -s ${dir_wrf}/* ${dir_exp}/${date_init}/mem${mem}/wrf
  else
    echo "WARNING: Could not build ${dir_exp}/${date_init}/mem${mem}/wrf, directory already exists!"
    echo "WARNING: WRF run directory was not linked to ${dir_exp}/${date_init}/mem${mem}/wrf"
  fi

done
