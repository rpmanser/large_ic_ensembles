#!/bin/bash

###############################################################################
# build_directories_downscale_GEFS.bash
#
# Create a directory structure for a downscaled GEFS WRF ensemble forecasting system.
#
# Parameters
# ----------
#   $1 = param : parameter file containing paths to WRF directories
#   $2 = init : date of forecast initialization
#   $3 = num_mem : number of ensemble members
###############################################################################

param=$1
init=$2
num_mem=$3
source $param

dir_exp=${dir_scratch}/downscale_GEFS

echo "Path to build directories in: "${dir_exp}
echo "Path to WPS directory: "${dir_wps}
echo "Path to WRF directory: "${dir_wrf}

mkdir -p ${dir_exp}/${init}

cd ${dir_exp}/${init}

# Build data, wps, and wrf directories for each member
# Link wps and wrf directories to each respective member directory
for mem in `seq 1 ${num_mem}` ; do

  # Build and link WPS directory
  if [ ! -d "${dir_exp}/${init}/mem${mem}/wps" ] ; then
    mkdir -p ${dir_exp}/${init}/mem${mem}/wps
    ln -rs ${dir_wps}/* ${dir_exp}/${init}/mem${mem}/wps

  else
    echo "WARNING: Could not build "${dir_exp}/${init}/mem${mem}/wps", directory already exists!"
    echo "WARNING: WPS directory was not linked to "${dir_exp}/${init}/mem${mem}/wps
  fi

  # Build and link WRF directory
  if [ ! -d "${dir_exp}/${init}/mem${mem}/wrf" ] ; then
    mkdir -p ${dir_exp}/${init}/mem${mem}/wrf
    ln -s ${dir_wrf}/* ${dir_exp}/${init}/mem${mem}/wrf
  else
    echo "WARNING: Could not build "${dir_exp}/${init}/mem${mem}/wrf", directory already exists!"
    echo "WARNING: WRF run directory was not linked to "${dir_exp}/${init}/mem${mem}/wrf
  fi

done
