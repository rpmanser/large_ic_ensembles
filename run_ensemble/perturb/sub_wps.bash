#!/bin/sh
#SBATCH -D ./
#SBATCH -J wps_gfsp
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -t 24:00:00
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=3

# ============================================================================================
# sub_wps.bash
#
# Run ungrib, metgrid, and real for a single WRF initialization from GFS ICs/BCs
#
# This script assumes you have the following variable table in your wps dir:
#   Vtable.GFS_newJan2015
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF info
#   $2 = date_begin : forecast intialization date (YYYYMMDDHH)
#   $3 = date_end : date_end forecast date (YYYYMMDDHH)
#   $4 = exp (optional) : ensemble experiment name. Default is 'perturb_GFS'
#   $5 = sixhr (optional) : set to 'true' to use a six hour forecast as ICs/BCs
#     instead of an analysis. Default is 'false'.
#
# Authors: Brian Ancell, Russell Manser
# ============================================================================================

module load intel impi netcdf-serial hdf5

param=$1
source $param
date_begin=$2
date_end=$3
exp=${4:-perturb_GFS}
sixhr=${5:-false}

dir_data=/lustre/research/bancell/SE2016/${date_begin}

num_metgrid_levels=27

if [[ "$sixhr" == "false" ]]; then
  dir_exp=/lustre/scratch/rmanser/${exp}/${date_begin}/gfs_icbc
  dir_data=/lustre/research/bancell/SE2016/${date_begin}
elif [[ "$sixhr" == "true" ]]; then
  prev=`python /home/rmanser/ic_ensembles/modify_date.py $date_begin -12`
  dir_data=/lustre/research/bancell/SE2016/${prev}
fi

# Run ungrib.exe
# --------------------------------------------------------------------------------------------

cd ${dir_exp}/wps

rm -f ${dir_exp}/wps/ungrib.log
rm -f ${dir_exp}/wps/namelist.wps

if [ -e ${dir_exp}/wps/Vtable ] ; then
  unlink Vtable
fi
ln -s ${dir_exp}/wps/ungrib/Variable_Tables/Vtable.GFS_newJan2015 ${dir_exp}/wps/Vtable

${dir_base}/run_ensemble/make_namelist_WPSV3.5.1.bash \
$param $date_begin $date_end ${dir_exp}/wps

if [[ "$sixhr" == "false" ]]; then
  ${dir_exp}/wps/link_grib.csh ${dir_data}/gfs_* .
elif [[ "$sixhr" == "true" ]]; then
  ${dir_exp}/wps/link_grib.csh ${dir_data}/gfs_${prev}_f[!00]* .
fi

${dir_exp}/wps/ungrib.exe

mv ${dir_exp}/wps/ungrib.log ${dir_log}/ungrib_GFS_log_${date_begin}
rm -f ${dir_exp}/wps/GRIBFILE*

# Run metgrid.exe
# --------------------------------------------------------------------------------------------

rm -f ${dir_exp}/wps/metgrid.log

${dir_exp}/wps/metgrid.exe

rm -f ${dir_exp}/FILE*
rm -f ${dir_exp}/GFS*
mv ${dir_exp}/wps/metgrid.log ${dir_log}/metgrid_log_${date_begin}

# Run real.exe
# --------------------------------------------------------------------------------------------

cd ${dir_exp}/wrf

rm -f ${dir_exp}/wrf/namelist.input
${dir_base}/run_ensemble/make_namelist_WRFV3.5.1.bash \
$param $date_begin $date_end ${dir_exp}/wrf $num_metgrid_levels

ln -s ${dir_exp}/wps/met_em* ${dir_exp}/wrf
${dir_exp}/wrf/real.exe

mv ${dir_exp}/wrf/wrfinput_d0? ${dir_exp}
mv ${dir_exp}/wrf/wrfbdy_d0? ${dir_exp}

if [[ -e "${dir_exp}/wrfinput_d01" ]]; then
  mv ${dir_exp}/wrf/rsl.out.0000 ${dir_log}/real_out_${date_begin}
  mv ${dir_exp}/wrf/rsl.error.0000 ${dir_log}/real_error_${date_begin}
  rm ${dir_exp}/wrf/*
  rm ${dir_exp}/wps/*
  rmdir ${dir_exp}/wrf
  rmdir ${dir_exp}/wps
fi
