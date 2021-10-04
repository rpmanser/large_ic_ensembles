#!/bin/bash
#SBATCH -D ./
#SBATCH -J verifconv
#SBATCH -o %x.o%j
#SBATCH -e %x.e%j
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=6

# Forecast keys
# -------------
# nmep_precipitation_{threshold}_{decimal}
# nmep_reflectivity_{threshold}_{decimal}
# nmep_updraft_helicity_{threshold}_{decimal}

# Observation keys
# ----------------
# precipitation_{threshold}_{decimal}
# col_max_refl_{threshold}
# practically_perfect_probabilities

fcst_key=$1
obs_key=$2
radius_idx=$3
exp=${4:-""}
perturbed=${5:-false}

echo "Forecast key: $fcst_key"
echo "Observation key: $obs_key"
echo "Radius index: $radius_idx"
echo "Experiment: $exp"
echo "Verify perturbed experiments: $perturbed"

pyenv=/home/rmanser/software/miniconda3/envs/ens/bin/python

dir_tmp=tmp_${fcst_key}_r${radius_idx}
dir_out=/lustre/scratch/rmanser/verif

if [[ "$exp" != "" ]]; then
  $pyenv /home/rmanser/scripts/verify_convective.py $exp $fcst_key $obs_key $radius_idx $dir_out
elif [[ "$perturbed" == "false" ]]; then
  # for exp in downscale_GEFS perturb_GFS_fixed SE2016 recenter ; do
  for exp in perturb_GFS ; do
    $pyenv /home/rmanser/scripts/verify_convective.py $exp $fcst_key $obs_key $radius_idx $dir_out
  done
# Verify the perturbed/scaled experiments
elif [[ "$perturbed" == "true" ]]; then
  #statements
  init_start=2016052212
  init_end=2016052912

  # for expn in `seq 1 7`; do
  #   exp=perturb_GFS_exps/exp${expn}
  #
  #   $pyenv /home/rmanser/scripts/verify_convective.py $exp $fcst_key $obs_key $radius_idx \
  #   $dir_out --init_start $init_start --init_end $init_end
  # done

  for expn in 09 11; do
    rckf=recenter_scaled_${expn}
    gefs=downscale_GEFS_scaled_${expn}

    $pyenv /home/rmanser/scripts/verify_convective.py $gefs $fcst_key $obs_key $radius_idx \
    $dir_out --init_start $init_start --init_end $init_end

    $pyenv /home/rmanser/scripts/verify_convective.py $rckf $fcst_key $obs_key $radius_idx \
    $dir_out --init_start $init_start --init_end $init_end
  done
fi

# time $pyenv /home/rmanser/scripts/verify_convective.py $exp $fcst_key $obs_key $radius_idx $dir_out
