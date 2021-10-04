#!/bin/bash
# =============================================================================
# move_and_clean.bash
#
# Move important files in a WRF member directory, then remove the directory
# and its contents if it contains no important files. Important files are:
# - Any wrfout file (not moved, only checked for)
# - wrfinput_d01, wrfinput_d02, wrfbdy_d01 (moved up one directory)
# - namelist.input, parame.in (moved up one directory)
#
# Parameters
# ----------
# $1 = param : paramter file containing WRF settings and paths
# $2 = exp : experiment directory to clean
# $3 = init : initialization date directory to clean
# $4 = mem : member directory to clean
# =============================================================================

param=$1
exp=$2
init=$3
mem=$4

source $param

dir_exp=${dir_scratch}/${exp}

echo "Cleaning WRF directories in ${dir_exp}/${init}/mem${mem}"

# Move wrfout, wrfinput, and wrfbdy files up one directory
if [[ -e "${dir_exp}/${init}/mem${mem}/wrf/wrfinput_d01" ]]; then
  mv ${dir_exp}/${init}/mem${mem}/wrf/wrfinput_d01 ${dir_exp}/${init}/mem${mem}
fi
if [[ -e "${dir_exp}/${init}/mem${mem}/wrf/wrfinput_d02" ]]; then
  mv ${dir_exp}/${init}/mem${mem}/wrf/wrfinput_d02 ${dir_exp}/${init}/mem${mem}
fi
if [[ -e "${dir_exp}/${init}/mem${mem}/wrf/wrfbdy_d01" ]]; then
  mv ${dir_exp}/${init}/mem${mem}/wrf/wrfbdy_d01 ${dir_exp}/${init}/mem${mem}
fi

# Move namelist files up one directory
if [[ -e "${dir_exp}/${init}/mem${mem}/wrf/namelist.input" ]]; then
  mv ${dir_exp}/${init}/mem${mem}/wrf/namelist.input ${dir_exp}/${init}/mem${mem}
fi
if [[ -e "${dir_exp}/${init}/mem${mem}/wrfvar/parame.in" ]]; then
  mv ${dir_exp}/${init}/mem${mem}/wrfvar/parame.in ${dir_exp}/${init}/mem${mem}
fi

# Double check that we moved all the files before deleting dirs
if [[ ! -n "$(find "${dir_exp}/${init}/mem${mem}/wrf/" -maxdepth 1 -name 'wrfout_d0*' -print -quit)" ]] && \
[[ ! -n "$(find "${dir_exp}/${init}/mem${mem}/wrf/" -maxdepth 1 -name 'wrfinput_d0*' -print -quit)" ]] && \
[[ ! -n "$(find "${dir_exp}/${init}/mem${mem}/wrf/" -maxdepth 1 -name 'wrfbdy_d0*' -print -quit)" ]] && \
[[ ! -e "${dir_exp}/${init}/mem${mem}/wrf/namelist.input" ]] && \
[[ ! -e "${dir_exp}/${init}/mem${mem}/wrfvar/parame.in" ]]; then

  echo "Removing ${dir_exp}/${init}/mem${mem}/wrf"
  rm -f ${dir_exp}/${init}/mem${mem}/wrf/*
  if [[ -e "${dir_exp}/${init}/mem${mem}/wrf" ]]; then
    rmdir ${dir_exp}/${init}/mem${mem}/wrf
  fi

  echo "Removing ${dir_exp}/${init}/mem${mem}/wps"
  rm -f ${dir_exp}/${init}/mem${mem}/wps/*
  if [[ -e "${dir_exp}/${init}/mem${mem}/wps" ]]; then
    rmdir ${dir_exp}/${init}/mem${mem}/wps
  fi

  echo "Removing ${dir_exp}/${init}/mem${mem}/wrfvar"
  rm -f ${dir_exp}/${init}/mem${mem}/wrfvar/*
  if [[ -e "${dir_exp}/${init}/mem${mem}/wrfvar" ]]; then
    rmdir ${dir_exp}/${init}/mem${mem}/wrfvar
  fi

else
  echo "Found one or more files that you should keep within the dirs to be deleted. Aborting operation"
fi
