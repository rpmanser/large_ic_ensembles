#!/bin/bash

###############################################################################
# build_directories_perturb_GFS.bash
#
# Create a directory structure for a WRF ensemble forecasting system
# initialized with perturbed GFS ICs.
#
# Parameters
# ----------
#   $1 = param : parameter file containing paths and WRF info
#   $2 = init : forecast initialization date (i.e., name of parent directory)
#   $3 = num_mem : number of ensemble members
#   $4 = dir_name (optional) : name of the ensemble parent directory. Default is 'perturb_GFS'
###############################################################################

param=$1
init=$2
num_mem=$3
dir_name=${4:-perturb_GFS}
source $param

dir_exp=${dir_scratch}/${dir_name}
mkdir -p ${dir_exp}/${init}
cd ${dir_exp}/${init}

dir_icbc=${dir_exp}/${init}/gfs_icbc

# Build and link a single WPS directory for creating deterministic GFS ICs/BCs
if [ ! -d "${dir_icbc}/wps" ] ; then
  mkdir -p ${dir_icbc}/wps
  ln -rsf ${dir_wps}/* ${dir_icbc}/wps
else
  echo "WARNING: Could not build ${dir_icbc}/wps, directory already exists!"
  echo "WARNING: WPS directory was not linked to ${dir_icbc}/wps"
fi

# Similarly for a WRF directory
if [ ! -d "${dir_icbc}/wrf" ] ; then
  mkdir -p ${dir_icbc}/wrf
  ln -sf ${dir_wrf}/* ${dir_icbc}/wrf
else
  echo "WARNING: Could not build ${dir_icbc}/wrf, directory already exists!"
  echo "WARNING: WRF run directory was not linked to ${dir_icbc}/wrf"
fi

for mem in `seq 1 ${num_mem}` ; do

  if [ ! -d "${dir_exp}/${init}/mem${mem}/wrf" ] ; then
    mkdir -p ${dir_exp}/${init}/mem${mem}/wrf
    ln -sf ${dir_wrf}/* ${dir_exp}/${init}/mem${mem}/wrf
  else
    echo "WARNING: Could not build ${dir_exp}/${init}/mem${mem}/wrf, directory already exists!"
    echo "WARNING: WRF run directory was not linked to ${dir_exp}/${init}/mem${mem}/wrf"
  fi

  if [ ! -d "${dir_exp}/${init}/mem${mem}/wrfvar" ] ; then
    mkdir -p ${dir_exp}/${init}/mem${mem}/wrfvar
    ln -sf ${dir_wrfvar}/var/da/da_wrfvar.exe ${dir_exp}/${init}/mem${mem}/wrfvar
    ln -sf ${dir_wrfvar}/var/da/da_update_bc.exe ${dir_exp}/${init}/mem${mem}/wrfvar
    ln -sf ${dir_wrfvar}/var/run/be.dat.cv3 ${dir_exp}/${init}/mem${mem}/wrfvar/be.dat
    ln -sf ${dir_wrfvar}/run/LANDUSE.TBL ${dir_exp}/${init}/mem${mem}/wrfvar
  else
    echo "WARNING: Could not build ${dir_exp}/${init}/mem${mem}/wrfvar, directory already exists!"
    echo "WARNING: WRF run directory was not linked to ${dir_exp}/${init}/mem${mem}/wrfvar"
  fi

done
