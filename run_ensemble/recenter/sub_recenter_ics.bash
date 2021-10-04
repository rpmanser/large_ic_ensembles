#!/bin/sh
#SBATCH -D ./
#SBATCH -J recenter_ics
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=3
#SBATCH -t 24:00:00

# ============================================================================================
# sub_recenter_ics.bash
#
# Generate initial conditions for an ensemble by differencing out perturbations
# from the mean of an existing ensemble, then adding those to a new analysis.
#
# Parameters
# ----------
#   $1 = param : path to parameter file containing paths and WRF variables
#   $2 = date_init : forecast initialization date (YYYYMMDDHH)
# ============================================================================================

module load intel netcdf-serial hdf5

param=$1
date_init=$2
source $param

NUM_MEM=2
nco=/home/rmanser/software/miniconda3/envs/nco/bin

# =============================================================================
# Setup
# =============================================================================

dir_exp=${dir_scratch}/recenter/${date_init}
dir_gfs=${dir_scratch}/perturb_GFS_fixed/${date_init}/gfs_icbc
dir_mean=${dir_scratch}/recenter/${date_init}/enkf_mean

# Determine the location of the EnKF files
if [ $date_init -le $date_research ]; then
  dir_enkf=$dir_enkf_research
elif [ $date_init -le $date_work ]; then
  dir_enkf=$dir_enkf_work
elif [ $date_init -le $date_scratch ]; then
  dir_enkf=$dir_enkf_scratch
fi

# Make a temporary directory for calculating perturbations
mkdir ${dir_exp}/perturbations
cd ${dir_exp}/perturbations

# Copy control member forecast (GFS ICs) to re-centered member 1 wrf directory
cp ${dir_gfs}/wrfinput_d01 ${dir_exp}/perturbations/wrfinput_d01_gfs
cp ${dir_gfs}/wrfinput_d02 ${dir_exp}/perturbations/wrfinput_d02_gfs

# Calculate the EnKF mean and do not delete the member ICs
${dir_base}/run_ensemble/recenter/calc_mean.bash $param $date_init

# =============================================================================
# Loop over EnKF members and do the following:
# 1) Calculate EnKF perturbations by subtracting the EnKF mean from each EnKF member
# 2) Add EnKF perturbations to GFS ICs to get re-centered ICs
# 3) Copy EnKF BCs to respective re-centered member directories, and update them
# =============================================================================

for mem in `seq 1 $NUM_MEM`; do
  echo "Working on member "${mem}"..."

  #
  # 1) Calculate perturbations by subtracting the mean from each member
  #

  echo "Calculating perturbations..."
  ${nco}/ncbo --op_typ='-' -O ${dir_mean}/wrfinput_d01_mem${mem} \
  ${dir_mean}/wrfinput_d01_mean \
  ${dir_exp}/perturbations/wrfinput_d01_pert_mem${mem}

  ${nco}/ncbo --op_typ='-' -O ${dir_mean}/wrfinput_d02_mem${mem} \
  ${dir_mean}/wrfinput_d02_mean \
  ${dir_exp}/perturbations/wrfinput_d02_pert_mem${mem}

  #
  # 2) Add perturbations to analysis ICs to get re-centered ICs
  #

  # Input for domain 1 is named wrfvar_output so make_namelist_updatebc.bash can be reused...
  echo "Calculating new initial conditions..."

  ${nco}/ncbo --op_typ='+' -O ${dir_exp}/perturbations/wrfinput_d01_pert_mem${mem} \
  ${dir_exp}/perturbations/wrfinput_d01_gfs ${dir_exp}/mem${mem}/wrf/wrfvar_output

  ${nco}/ncbo --op_typ='+' -O ${dir_exp}/perturbations/wrfinput_d02_pert_mem${mem} \
  ${dir_exp}/perturbations/wrfinput_d02_gfs ${dir_exp}/mem${mem}/wrf/wrfinput_d02

  cd ${dir_exp}/mem${mem}/wrf

  #
  # 3) Copy BCs to respective re-centered member directories and update them
  #

  echo "Copying BCs to "${dir_exp}/mem${mem}/wrf"..."
  if [ -e "${dir_enkf}/${date_init}/mem${mem}/wrfbdy_d01" ]; then
    ext=""
  elif [ -e "${dir_enkf}/${date_init}/mem${mem}/wrfbdy_d01.gz" ]; then
    ext=".gz"
  fi

  rsync --progress -iropg ${dir_enkf}/${date_init}/mem${mem}/wrfbdy_d01${ext} \
  ${dir_exp}/mem${mem}/wrf

  if [ "$ext" == ".gz" ]; then
    unpigz ${dir_enkf}/${date_init}/mem${mem}/wrfbdy_d01.gz
  fi

  echo "Updating BCs for domain 1..."
  ${dir_base}/run_ensemble/make_namelist_updatebc.bash ${dir_exp}/mem${mem}/wrf
  ln -sf ${dir_wrfvar}/var/da/da_update_bc.exe ${dir_exp}/mem${mem}/wrf
  ${dir_exp}/mem${mem}/wrf/da_update_bc.exe

  echo "Cleaning up member directory..."
  mv ${dir_exp}/mem${mem}/wrf/wrfvar_output \
  ${dir_exp}/mem${mem}/wrf/wrfinput_d01
  unlink ${dir_exp}/mem${mem}/wrf/da_update_bc.exe
  rm ${dir_exp}/mem${mem}/wrf/fort.1?
  rm ${dir_mean}/wrfinput_d01_mem${mem}
  rm ${dir_mean}/wrfinput_d02_mem${mem}
done

echo "Removing directory "${dir_exp}/perturbations"..."
rm -rf ${dir_exp}/perturbations
