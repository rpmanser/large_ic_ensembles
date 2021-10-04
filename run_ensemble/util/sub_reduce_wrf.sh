#!/bin/sh
#SBATCH -D ./
#SBATCH -J red_wrf
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -p quanah
#SBATCH -t 06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH -a 1-42%4

# ============================================================================================
# sub_reduce_wrf.sh
#
# Reduce WRF ensemble member files to only variables we care about. See the 'vars_to_keep'
# variable below.
#
# Reduced files are formatted as 'wrfoutred_d0<domain>_<year>-<month>-<day>_<hour>:00:00'
# and moved into a new directory 'wrfoutred' within the member directory.
#
# wrfinput_d0<domain> and wrfbdy_d01 files are moved to 'wrfoutred' as well.
#
# Parameters
# ----------
#   $1 = param : paramter file containing WRF settings and paths
#   $1 = exp : ensemble experiment name
#   $2 = date_begin : ensemble forecast date_beginialization date (YYYYMMDDHH)
# ============================================================================================

module load gnu nco

param=$1
exp=$2
date_begin=$3

source $param

mem=$SLURM_ARRAY_TASK_ID

dir_exp=${dir_scratch}/${exp}
date_end=`python ${dir_base}/modify_date.py $date_begin 48`
vars_to_keep="Q2,T2,U10,V10,U,V,W,T,PH,MU,QVAPOR,RAINC,RAINNC,P,TH2,PSFC,QCLOUD,QRAIN,QICE,QSNOW,QGRAUP,REFL_10CM,WSPD10MAX,W_UP_MAX,UP_HELI_MAX"

# Create reference files for each domain
mkdir -p ${dir_scratch}/wrfref
if [ ! -e "${dir_scratch}/wrfref/wrfoutREFd01" ] ; then
  cp ${dir_exp}/${date_begin}/mem1/wrf/wrfout_d01_${year}-${month}-${day}_${hour}:00:00 \
  ${dir_exp}/${date_begin}/wrfoutREFd01
fi
if [ ! -e "${dir_scratch}/wrfref/wrfoutREFd02" ] ; then
  cp ${dir_exp}/${date_begin}/mem1/wrf/wrfout_d02_${year}-${month}-${day}_${hour}:00:00 \
  ${dir_exp}/${date_begin}/wrfoutREFd02
fi

cd ${dir_exp}/${date_begin}/mem${mem}/wrf

# Create a wrfout reduced storage directory for the ensemble member
if [ ! -d "${dir_exp}/${date_begin}/mem${mem}/wrfoutred" ] ; then
  mkdir ${dir_exp}/${date_begin}/mem${mem}/wrfoutred
fi

date=$date_begin
while [ $date -le $date_end ] ; do

  dir_wrf=${dir_exp}/${date_begin}/mem${mem}/wrf
  dir_wrfoutred=${dir_exp}/${date_begin}/mem${mem}/wrfoutred

  hour=`echo $date | cut -b9-10`
  year=`echo $date | cut -b1-4`
  month=`echo $date | cut -b5-6`
  day=`echo $date | cut -b7-8`

  ncks -C -v $vars_to_keep wrfout_d01_${year}-${month}-${day}_${hour}:00:00 \
  wrfout_d01_red_${year}-${month}-${day}_${hour}:00:00

  ncks -C -v $vars_to_keep wrfout_d02_${year}-${month}-${day}_${hour}:00:00 \
  wrfout_d02_red_${year}-${month}-${day}_${hour}:00:00

  # Move the reduced wrfout files to the reduced storage directory
  mv ${dir_wrf}/wrfout_d01_red_${year}-${month}-${day}_${hour}:00:00 ${dir_wrfoutred}
  mv ${dir_wrf}/wrfout_d02_red_${year}-${month}-${day}_${hour}:00:00 ${dir_wrfoutred}

  # Delete the original wrfout files if running ncks -C -v produced a file
  if [ -e "${dir_wrfoutred}/wrfout_d01_red_${year}-${month}-${day}_${hour}:00:00" ] ; then
    rm ${dir_wrf}/wrfout_d01_${year}-${month}-${day}_${hour}:00:00
  fi
  if [ -e "${dir_wrfoutred}/wrfout_d02_red_${year}-${month}-${day}_${hour}:00:00" ] ; then
    rm ${dir_wrf}/wrfout_d02_${year}-${month}-${day}_${hour}:00:00
  fi

  date=`python ${dir_base}/modify_date.py $date 1`

done

# Move wrfinput and wrfbdy files to the reduced storage directory
mv ${dir_exp}/${date_begin}/mem${mem}/wrf/wrfinput_d01 \
${dir_exp}/${date_begin}/mem${mem}/wrfoutred
mv ${dir_exp}/${date_begin}/mem${mem}/wrf/wrfinput_d02 \
${dir_exp}/${date_begin}/mem${mem}/wrfoutred
mv ${dir_exp}/${date_begin}/mem${mem}/wrf/wrfbdy_d01 \
${dir_exp}/${date_begin}/mem${mem}/wrfoutred
