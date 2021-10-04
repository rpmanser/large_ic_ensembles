#!/bin/sh
#SBATCH -D ./
#SBATCH -J scale_ics
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=3
#SBATCH -t 24:00:00

# ============================================================================================
# sub_scale_perturbations.bash
#
# Parameters
# ----------
#   $1 = exp : ensemble experiment name
#   $2 = init : forecast initialization date formatted as YYYYMMDDHH
#   $3 = scale_factor : scalar to multiply prognostic ICs by
#   $4 = nmem : number of ensemble members. Default is 42
#   $5 = zipped : the ensemble ICs are zipped. Valid values are 'true' and 'false'
# ============================================================================================

module load intel
module load nco/4.7.3

exp=$1
init=$2
scale_factor="$3"
nmem=${4:-42}
zipped=${5:-true}

# =============================================================================
# Setup
# =============================================================================

nco=/home/rmanser/software/miniconda3/envs/nco/bin

scale_factor_str=${scale_factor//.}

pypath=/home/rmanser/software/miniconda3/envs/ensembles/bin/python
dir_base=/home/rmanser/ic_ensembles
dir_exp=/lustre/research/bancell/rmanser/${exp}/${init}
dir_gfs=/lustre/scratch/rmanser/gfs_icbc/${init}
dir_tmp=/lustre/scratch/rmanser/tmp_scale_ics/${exp}/${init}/${scale_factor_str}
dir_exp_scaled=/lustre/scratch/rmanser/${exp}_scaled_${scale_factor_str}/${init}

echo "Arguments"
echo "-------------------------------------------------------------------------"
echo "exp = $exp"
echo "init = $init"
echo "scale_factor = $scale_factor"
echo "nmem = $nmem"
echo "zipped = $zipped"

echo "Paths"
echo "-------------------------------------------------------------------------"
echo "pypath = $pypath"
echo "dir_base = $dir_base"
echo "dir_exp = $dir_exp"
echo "dir_gfs = $dir_gfs"
echo "dir_tmp = $dir_tmp"
echo "dir_exp_scaled = $dir_exp_scaled"
echo ""

# Clean up anything left from a previous run
rm -f ${dir_tmp}/wrfvar/*
rm -f ${dir_tmp}/*

mkdir -p $dir_tmp
mkdir -p $dir_exp_scaled

if [[ "$zipped" == "true" ]]; then
  ext=.gz
else
  ext=""
fi

cd $dir_tmp

# =============================================================================
# Copy ICs to a new directory
# =============================================================================

echo "Copying $exp ICs to $dir_tmp..."

for mem in `seq 1 ${nmem}`; do
  rsync --progress -iropg ${dir_exp}/mem${mem}/wrfoutred/wrfinput_d01${ext} \
  ${dir_tmp}/wrfinput_d01_mem${mem}${ext}
  rsync --progress -iropg ${dir_exp}/mem${mem}/wrfoutred/wrfinput_d02${ext} \
  ${dir_tmp}/wrfinput_d02_mem${mem}${ext}
  rsync --progress -iropg ${dir_exp}/mem${mem}/wrfoutred/wrfbdy_d01${ext} \
  ${dir_tmp}/wrfbdy_d01_mem${mem}${ext}
done

if [[ "$zipped" == "true" ]]; then
  unpigz wrfinput_d0?_mem*.gz
  unpigz wrfbdy_d01_mem*.gz
fi

# =============================================================================
# Calculate/copy the central IC state
# =============================================================================

if [[ "$exp" == "recenter" ]]; then
  rsync --progress -iropg ${dir_gfs}/wrfinput_d01 ${dir_tmp}/center_input_d01
  rsync --progress -iropg ${dir_gfs}/wrfinput_d02 ${dir_tmp}/center_input_d02
elif [[ "$exp" == "downscale_GEFS" ]]; then
  ${nco}/nces -O ${dir_tmp}/wrfinput_d01_mem*[0-9] ${dir_tmp}/center_input_d01
  ${nco}/nces -O ${dir_tmp}/wrfinput_d02_mem*[0-9] ${dir_tmp}/center_input_d02
fi

# =============================================================================
# Scale and add perturbations to central state
# =============================================================================

mkdir ${dir_tmp}/wrfvar

for mem in `seq 1 ${nmem}`; do

  destination=${dir_exp_scaled}/mem${mem}/wrf
  mkdir -p ${destination}

  for domain in 1 2; do

    if [[ -e "${dir_tmp}/wrfinput_d0${domain}_mem${mem}" ]]; then
      ${nco}/ncbo --op_typ='-' -O ${dir_tmp}/wrfinput_d0${domain}_mem${mem} \
      ${dir_tmp}/center_input_d0${domain} \
      ${dir_tmp}/wrfinput_d0${domain}_pert_mem${mem}

      for variable in U V PH T MU QVAPOR; do
        ${nco}/ncap2 -s "${variable}=${variable}*${scale_factor}" \
        ${dir_tmp}/wrfinput_d0${domain}_pert_mem${mem}
      done

      ${nco}/ncbo --op_typ='+' -O ${dir_tmp}/wrfinput_d0${domain}_pert_mem${mem} \
      ${dir_tmp}/center_input_d0${domain} \
      ${destination}/wrfinput_d0${domain}

    else
      echo "*** WARNING: file ${dir_tmp}/wrfinput_d0${domain}_mem${mem} does not exist" >> \
      $JOB_NAME.$JOB_ID.error
    fi

  done

  # Copy lateral boundary conditions to wrfvar directory and update them
  cd ${dir_tmp}/wrfvar
  mv ${dir_tmp}/wrfbdy_d01_mem${mem} ${dir_tmp}/wrfvar/wrfbdy_d01
  cp ${destination}/wrfinput_d01 ${dir_tmp}/wrfvar/wrfvar_output

  ln -sf ${WORK}/WRFDAV3.5.1serial/var/da/da_update_bc.exe ${dir_tmp}/wrfvar
  ${dir_base}/run_ensemble/make_namelist_updatebc.bash ${dir_tmp}/wrfvar
  ${dir_tmp}/wrfvar/da_update_bc.exe

  mv ${dir_tmp}/wrfvar/wrfbdy_d01 ${destination}/wrfbdy_d01
done

rm ${dir_tmp}/wrfvar/*
rmdir ${dir_tmp}/wrfvar
rm ${dir_tmp}/*
rmdir ${dir_tmp}
