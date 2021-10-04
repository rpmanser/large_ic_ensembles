#!/bin/bash

# ============================================================================================
# Zip WRF ensemble members for a single initialization and forecast hour
#
# Parameters
# ----------
# $1 = param : parameter file containing WRF settings and paths
# $2 = exp : ensemble experiment name
# $3 = init : forecast initialization date (YYYYMMDDHH)
# $4 = hour : forecast hour
# $5 = domain : forecast domain number
# $6 = mem : ensemble member number
# ============================================================================================

param=$1
exp=$2
init=$3
hour=$4
domain=$5
mem=$6

source $param

dir_zip=${dir_scratch}/${exp}/${init}/mem${mem}/wrfoutred

date_fcst=`python ${dir_base}/modify_date.py $init $hour`

year=`echo $date_fcst | cut -b1-4`
month=`echo $date_fcst | cut -b5-6`
day=`echo $date_fcst | cut -b7-8`
hour=`echo $date_fcst | cut -b9-10`

filename=wrfout_d0${domain}_red_${year}-${month}-${day}_${hour}:00:00

if [[ -e "${dir_zip}/${filename}.gz" ]]; then
  echo "${dir_zip}/${filename}.gz already exists. Removing any unzipped files if present..."
  rm -f ${dir_zip}/${filename}
else
  echo "Zipping ${dir_zip}/${filename}..."
  pigz ${dir_zip}/${filename}
fi
