#!/bin/bash

# Checks if wps and real completed by looking for wrfinput_d01, wrfinput_d02, and wrfbdy_d01

exp=$1
init=$2

NUM_MEM=42
dir_exp=/lustre/scratch/rmanser/${exp}

for mem in `seq 1 ${NUM_MEM}` ; do
  cd ${dir_exp}/${init}/mem${mem}/wrf

  d01=true
  d02=true
  bdy=true

  if [ ! -e "${dir_exp}/${init}/mem${mem}/wrf/wrfinput_d01" ] ; then
    d01=false
  fi

  if [ ! -e "${dir_exp}/${init}/mem${mem}/wrf/wrfinput_d02" ] ; then
    d02=false
  fi

  if [ ! -e "${dir_exp}/${init}/mem${mem}/wrf/wrfbdy_d01" ] ; then
    bdy=false
  fi

  if [ "${d01}" = "false" ] || [ "${d02}" = "false" ] || [ "${bdy}" = "false" ] ; then
    echo "real.exe failed for member ${mem}"
    if [ -e "${dir_log}/ungrib_GEFS_log_${init}_mem${mem}" ] ; then
      mv ${dir_log}/ungrib_GEFS_log_${init}_mem${mem} ${dir_log}/failed
    fi
    if [ -e "${dir_log}/ungrib_GFS_log_${init}_mem${mem}" ] ; then
      mv ${dir_log}/ungrib_GFS_log_${init}_mem${mem} ${dir_log}/failed
    fi
    if [ -e "${dir_log}/ungrib_log_${init}_mem${mem}" ] ; then
      mv ${dir_log}/ungrib_log_${init}_mem${mem} ${dir_log}/failed
    fi
    if [ -e "${dir_log}/metgrid_log_${init}_mem${mem}" ] ; then
      mv ${dir_log}/metgrid_log_${init}_mem${mem} ${dir_log}/failed
    fi
    if [ -e "${dir_log}/real_out_${init}_mem${mem}" ] ; then
      mv ${dir_log}/real_out_${init}_mem${mem} ${dir_log}/failed
    fi
    if [ -e "${dir_log}/real_error_${init}_mem${mem}" ] ; then
      mv ${dir_log}/real_error_${init}_mem${mem} ${dir_log}/failed
    fi
  fi

done
