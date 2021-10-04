#!/bin/sh
#SBATCH -D ./
#SBATCH -J wps_downscale
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -t 02:00:00
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=3
#SBATCH -a 1-42:1

###############################################################################
# sub_wps_downscale.bash
#
# Runs ungrib, metgrid, and real for an entire WRF ensemble initialized with GEFS
# and supplemented by GFS surface variables.
#
# This script assumes you have the following variables tables in your wps dir:
# - Vtable.CLARK.GFSENS: contains updated variables for the GFS ensemble
# - Vtable.SUPP: contains surface variables that are missing from GFS ensemble data
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF info
#   $2 = date_begin : forecast intialization date (YYYYMMDDHH)
#   $3 = date_end : final forecast date (YYYYMMDDHH)
#
# Authors: Brian Ancell, Russell Manser
###############################################################################

module load intel impi netcdf-serial hdf5

param=$1
date_begin=$2
date_end=$3
source $param

mem=$SLURM_ARRAY_TASK_ID

dir_exp=${dir_scratch}/downscale_GEFS/${date_begin}
dir_mem=${dir_exp}/mem${mem}
dir_scripts=${dir_base}/run_ensemble/downscale_GEFS

# For the first 21 members, the initialization date of the WRF and GEFS ensemble are the same
if [ $mem -le 21 ] ; then
  date_init=$date_begin
  gefs_mem=$mem
# For members 22-42, the initialization date of GEFS is 6 hours prior to the WRF initialization
elif [ $mem -gt 21 ] ; then
  let date_init=`python ${dir_base}/modify_date.py ${date_begin} 6`
  let gefs_mem='mem - 21'
fi

dir_data=/lustre/research/bancell/SE2016/${date_init}

cd ${dir_mem}/wps

# Run ungrib.exe for GEFS upper air initial conditions *AND* GFS surface initial conditions
# --------------------------------------------------------------------------------------------
for model in 'GEFS' 'GFS' ; do

  if [ -e ${dir_mem}/wps/ungrib.log ]; then
    rm ${dir_mem}/wps/ungrib.log
  fi
  if [ -e ${dir_mem}/wps/namelist.wps ]; then
    rm ${dir_mem}/wps/namelist.wps
  fi

  if [ -e ${dir_mem}/wps/Vtable ] ; then
    unlink ${dir_mem}/wps/Vtable
  fi

  if [ "$model" = "GEFS" ] ; then
    ln -s ${dir_mem}/wps/ungrib/Variable_Tables/Vtable.CLARK.GFSENS ${dir_mem}/wps/Vtable
  elif [ "$model" = "GFS" ] ; then
    ln -s ${dir_mem}/wps/ungrib/Variable_Tables/Vtable.SUPP ${dir_mem}/wps/Vtable
  fi

  ${dir_scripts}/make_namelist_wps_${model}.bash $param $date_init $date_end ${dir_mem}/wps

  if [ "$model" = "GEFS" ] ; then
    ${dir_mem}/wps/link_grib.csh ${dir_data}/GEFS/mem${gefs_mem}/gens*
  elif [ "$model" = "GFS" ] ; then
    ${dir_mem}/wps/link_grib.csh ${dir_data}/gfs*
  fi

  ${dir_mem}/wps/ungrib.exe

  if [ "$model" = "GEFS" ] ; then
    mv ${dir_mem}/wps/ungrib.log ${dir_log}/ungrib_GEFS_log_${date_begin}_mem${mem}
  elif [ "$model" = "GFS" ] ; then
    mv ${dir_mem}/wps/ungrib.log ${dir_log}/ungrib_GFS_log_${date_begin}_mem${mem}
  fi

  rm ${dir_mem}/wps/GRIBFILE*

done

# Run metgrid.exe
# --------------------------------------------------------------------------------------------
if [ -e ${dir_mem}/wps/metgrid.log ]; then
  rm ${dir_mem}/wps/metgrid.log
fi

${dir_mem}/wps/metgrid.exe

rm ${dir_mem}/wps/FILE*
rm ${dir_mem}/wps/GFS*
mv ${dir_mem}/wps/metgrid.log ${dir_log}/metgrid_log_${date_begin}_mem${mem}

# Run real.exe
# --------------------------------------------------------------------------------------------

cd ${dir_mem}/wrf

if [ -e ${dir_mem}/wrf/namelist.input ]; then
  rm ${dir_mem}/wrf/namelist.input
fi

${dir_scripts}/make_namelist_wrf_downscale.bash $param $date_init $date_end ${dir_mem}/wrf

ln -s ${dir_mem}/wps/met_em* ${dir_mem}/wrf

${dir_mem}/wrf/real.exe

mv ${dir_mem}/wrf/rsl.out.0000 ${dir_log}/real_out_${date_begin}_mem${mem}
mv ${dir_mem}/wrf/rsl.error.0000 ${dir_log}/real_error_${date_begin}_mem${mem}
rm ${dir_mem}/wrf/met_em*
rm ${dir_mem}/wps/met_em*
