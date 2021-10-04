#!/bin/bash

# ============================================================================================
# ens_stat_param.bash
#
# Parameter file for running MET ensemble_stat via
# ic_ensembles/verify/met_tools/ensemble_stat.bash
#
# Contents include directory paths used in ensemble_stat scripts and settings for the
# EnsembleStatConfig file.
# ============================================================================================

dir_base=${HOME}/ic_ensembles
dir_scripts=${dir_base}/verify/met_tools
dir_work=/lustre/work/rmanser
dir_scratch=/lustre/scratch/rmanser

PATH_WRFREF=/lustre/work/rmanser/wrfref
export PATH_WRFREF=$PATH_WRFREF

dir_save=${dir_scratch}/ens_stat_test
dir_met_tmp=${dir_scratch}/met_tmp
dir_zip=${dir_scratch}/${experiment}/${date_init}
dir_post=${dir_scratch}/wrf_post

met_container=${dir_work}/met-8.0.img

source activate met
python_met=`which python`

NUM_MEM=42

# EnsembleStatConfig
obs_type=raob
msg_type=ADPUPA
fcst_key=temperature
fcst_lvl=300
obs_key=TMP
obs_lvl=P300
dist_type="NONE"
dist_param=""
cat_thresh='<=200.0, >=245.0'
censor_thresh=$cat_thresh
censor_val='-9999, -9999'
