#!/bin/sh
#SBATCH -D ./
#SBATCH -J wrfvar_ens
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -t 24:00:00
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=36
#SBATCH -a 1-42:1

# ============================================================================================
# sub_wrfvar_ensemble.bash
#
# Initialize and run an ensemble with ICs produced by RANDOMCV.
#
# WRF boundary conditions from GEFS are required to run this ensemble. Please ensure they are
# located at <path/to/your/scratch>/downscale_GEFS/<init>/mem<mem>
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF info
#   $2 = init : forecast initialization date (YYYYMMDDHH)
#   $3 = exp (optional) : ensemble experiment directory name. Default is 'perturb_GFS'
#   $4 = sixhr (optional) : use ICs from a six-hour forecast instead of the analysis.
#     Can have values of 'true' and 'false'. Default is 'false'.
# ============================================================================================

param=$1
source $param
init=$2
exp=${3:-perturb_GFS}
sixhr=${4:-false}

module load intel netcdf-serial impi

mem=$SLURM_ARRAY_TASK_ID

if [[ "$sixhr" == "true" ]]; then
  dir_ics=${dir_scratch}/${exp}/${init}/gfs_icbc_sixhr
else
  dir_ics=${dir_scratch}/gfs_icbc/${init}
fi

dir_bcs=${dir_research}/downscale_GEFS/${init}/mem${mem}
dir_exp=${dir_scratch}/${exp}/${init}/mem${mem}

rsync ${dir_bcs}/wrfoutred/wrfbdy_d01.gz ${dir_exp}/wrfvar
unpigz ${dir_exp}/wrfvar/wrfbdy_d01.gz

if [[ ! -e "${dir_exp}/wrf/wrfinput_d02" ]]; then
  rsync ${dir_ics}/wrfinput_d02* ${dir_exp}/wrf
  if [[ -e "${dir_exp}/wrf/wrfinput_d02.gz" ]]; then
    unpigz ${dir_exp}/wrf/wrfinput_d02.gz
  fi
fi

${dir_base}/run_ensemble/perturb/gen_member_ics.bash \
$param $init $mem ${dir_scratch}/${exp} $dir_ics

date_end=`${dir_base}/modify_date.py $init 48`
${dir_base}/run_ensemble/make_namelist_WRFV3.5.1.bash $param $init $date_end ${dir_exp}/wrf

${dir_base}/run_ensemble/run_wrf_member.bash $param $init $exp $mem
