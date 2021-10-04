#!/bin/bash
# ============================================================================================
# run_wrf_member.bash
#
# Run a single WRF ensemble member forecast.
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF info
#   $2 = init : forecast intialization date (YYYYMMDDHH)
#   $3 = exp : ensemble experiment name
#   $4 = mem : ensemble member number
# ============================================================================================

module load intel/18.0.3.222
module load impi/2018.3.222
module load netcdf-serial/4.1.3
module load hdf5/1.8.20

param=$1
init=$2
exp=$3
mem=$4
source $param

dir_exp=${dir_scratch}/${exp}

date_end=`python ${dir_base}/modify_date.py $init 48`

if [[ ! -e "${dir_exp}/${init}/mem${mem}/wrf/wrf.exe" ]]; then
	ln -s ${dir_wrf}/* ${dir_exp}/${init}/mem${mem}/wrf/

	${dir_base}/run_ensemble/make_namelist_WRFV3.5.1.bash \
  $param $init $date_end ${dir_exp}/${init}/mem${mem}/wrf
fi

cd ${dir_exp}/${init}/mem${mem}/wrf

mpirun -n 36 ${dir_exp}/${init}/mem${mem}/wrf/wrf.exe


# If cfl errors exist, write only those lines to the error file
if cat rsl.error.* | grep 'cfl' -iq ; then
	grep 'cfl' -i rsl.error.* > ${dir_log}/wrf_error_${init}_mem${mem}
# Otherwise, write all lines to the error file
else
	cat rsl.error.* > ${dir_log}/wrf_error_${init}_mem${mem}
fi

mv rsl.out.0000 ${dir_log}/wrf_out_${init}_mem${mem}
rm ${dir_exp}/${init}/mem${mem}/wrf/rsl.*
