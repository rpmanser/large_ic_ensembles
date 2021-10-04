#!/bin/sh

# ============================================================================================
# gen_member_ics.bash
#
# Generate initial conditions for an ensemble member using RANDOMCV in WRFVAR.
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF info
#   $2 = init : forecast initialization date (YYYYMMDDHH)
#   $3 = mem : ensemble member number
#   $4 = dir_exp (optional) : absolute path to ensemble experiment parent directory.
#     Default is '/lustre/scratch/rmanser/perturb_GFS_fixed'.
#   $5 = dir_ics : absolute path to wrfinput files to perturb. Default is
#     '/lustre/scratch/rmanser/gfs_icbc'.
# ============================================================================================

module load intel/18.0.3.222
module load impi/2018.3.222
module load netcdf-serial/4.1.3
module load hdf5/1.8.20

param=$1
init=$2
mem=$3
dir_exp=${4:-/lustre/scratch/rmanser/perturb_GFS_fixed}
dir_ics=${5:-/lustre/scratch/rmanser/gfs_icbc}

source $param

dir_mem=${dir_exp}/${init}/mem${mem}

cd ${dir_mem}/wrfvar
ln -sf ${dir_ics}/wrfinput_d01 ${dir_mem}/wrfvar/fg
${dir_base}/run_ensemble/perturb/make_namelist_wrfvar.bash $param $init $mem ${dir_mem}/wrfvar
${dir_mem}/wrfvar/da_wrfvar.exe

rm buddy_check
rm check_max_iv
rm cost_fn
rm grad_fn
rm gts_omb_oma_01*
rm jo
rm qcstat_conv_01
rm rej_obs_conv_01.000
rm statistics
rm unpert_obs*

${dir_base}/run_ensemble/make_namelist_updatebc.bash ${dir_mem}/wrfvar
${dir_mem}/wrfvar/da_update_bc.exe
rm fort.1?

mv ${dir_mem}/wrfvar/wrfbdy_d01 ${dir_mem}/wrf/wrfbdy_d01
mv ${dir_mem}/wrfvar/wrfvar_output ${dir_mem}/wrf/wrfinput_d01
