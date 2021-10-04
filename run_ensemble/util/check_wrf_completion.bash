#!/bin/bash

# Checks if a wrf run completed by looking for the final forecast time

exp=$1
date_start=$2
num_mem=${3:-42}

source ../WRF_param_realtime_ens.bash

echo $dir_base

date_end=`python ${dir_base}/modify_date.py ${date_start} 48`

rhour=`echo $date_end | cut -b9-10`
ryear=`echo $date_end | cut -b1-4`
rmonth=`echo $date_end | cut -b5-6`
rday=`echo $date_end | cut -b7-8`

dir_exp=${dir_scratch}/${exp}
dir_log=${dir_base}/log

mkdir -p ${dir_log}/failed

for mem in `seq 1 ${num_mem}` ; do

  dir_mem=${dir_exp}/${date_start}/mem${mem}/wrf

  if [ ! -e "${dir_mem}/wrfout_d02_${ryear}-${rmonth}-${rday}_${rhour}:00:00" ] ; then
    echo "Member ${mem} failed!"
    if [ -e "${dir_log}/wrf_error_${date_start}_mem${mem}" ] ; then
      mv ${dir_log}/wrf_error_${date_start}_mem${mem} ${dir_log}/failed
    fi
    if [ -e "${dir_log}/wrf_out_${date_start}_mem${mem}" ] ; then
      mv ${dir_log}/wrf_out_${date_start}_mem${mem} ${dir_log}/failed
    fi
  fi
done
