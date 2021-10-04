#!/bin/sh
#SBATCH -D ./
#SBATCH -J wrf_ens
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -t 01:00:00
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=36
#SBATCH -a 22

###############################################################################
# sub_wrf_ensemble.bash
#
# Submission script for a generic wrf ensemble. ICs and BCs must already exist.
#
# Parameters
# ----------
#   $1 = param : parameter file containing paths and WRF info
#   $2 = init : forecast initialization date
#   $3 = exp : ensemble experiment directory name (not path)
########################################## #####################################

module load intel impi netcdf-serial hdf5
# module load intel/18.0.3.222
# module load netcdf-serial/4.1.3
# module load hdf5/1.8.20
# module load openmpi/1.10.7

param=$1
init=$2
exp=$3
source $param

dir_exp=${dir_scratch}/${exp}

mem=$SLURM_ARRAY_TASK_ID

if [[ "$exp" == "downscale_GEFS"* ]]; then
	namelist_script=${dir_base}/run_ensemble/downscale_GEFS/make_namelist_wrf_downscale.bash
else
  namelist_script=${dir_base}/run_ensemble/make_namelist_WRFV3.5.1.bash
fi

if [[ "$exp" == "downscale_GEFS"* ]] && [[ $mem -gt 21 ]]; then
	date_start=`python ${dir_base}/modify_date.py $init -6`
else
  date_start=$init
fi

dir_mem=${dir_exp}/${init}/mem${mem}/wrf

if [[ ! -d "${dir_mem}" ]]; then
  mkdir -p $dir_mem
  cd $dir_mem
  ln -s ${dir_wrf}/* .
fi

if [[ ! -e "${dir_mem}/wrfinput_d01" ]]; then

	if [[ -d "${dir_research}/${exp}/${init}/mem${mem}/wrfoutred" ]]; then
		rsync -iropg ${dir_research}/${exp}/${init}/mem${mem}/wrfoutred/wrfinput_d0?.gz .
		rsync -iropg ${dir_research}/${exp}/${init}/mem${mem}/wrfoutred/wrfbdy_d01.gz .
	else
		rsync -iropg ${dir_research}/${exp}/${init}/mem${mem}/wrfinput_d0?.gz .
		rsync -iropg ${dir_research}/${exp}/${init}/mem${mem}/wrfbdy_d01.gz .
	fi

	unpigz ${dir_mem}/wrfinput_d01.gz
	unpigz ${dir_mem}/wrfinput_d02.gz
	unpigz ${dir_mem}/wrfbdy_d01.gz
fi

if [[ ! -e "${dir_mem}/wrfinput_d01" ]] \
|| [[ ! -e "${dir_mem}/wrfinput_d02" ]] \
|| [[ ! -e "${dir_mem}/wrfbdy_d01" ]]; then
	echo "One or more input/bdy files are missing. Exiting..."
	exit 1
fi

date_end=`python ${dir_base}/modify_date.py $init 48`
${namelist_script} $param $date_start $date_end ${dir_exp}/${init}/mem${mem}/wrf

${dir_base}/run_ensemble/run_wrf_member.bash $param $init $exp $mem
