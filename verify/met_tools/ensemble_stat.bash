#!/bin/sh

# ============================================================================================
# ensemble_stat.bash
#
# Run the ensemble_stat tool from the Model Evaluation Tools for a single
# initialization and forecast time. Assumes ensemble members files are reduced and have
# the following naming convention:
#   wrfout_d0D_red_YYYY-MM-DD_HH:00:00
#
# Parameters
# ----------
#   $1 = param - full path to parameter file specifying variables in this script
#   $2 = date_init - forecast initialization date (YYYYMMDDHH)
#   $3 = fcst_hour - forecast hour to validate against obs
#   $4 = domain - forecast domain to verify against obs
#   $5 = experiment - ensemble experiment to validate
# ============================================================================================

module load singularity

param=$1
source $param
date_init=$2
fcst_hour=$3
domain=$4
experiment=$5

# =============================================================================
# Setup
# =============================================================================
dir_init=${dir_save}/${experiment}/${date_init}
dir_tmp=${dir_init}/tmp_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}

date_fcst=`python ${dir_base}/modify_date.py $date_init $fcst_hour`

# Create a save directory for the verification files
mkdir -p ${dir_init}
mkdir -p ${dir_met_tmp}

# Create a temporary directory for intermediate files
rm -rf ${dir_tmp}
mkdir -p ${dir_tmp}

# Generate the ensemble_stat configuration file
${dir_scripts}/make_EnsembleStatConfig.bash $param $dir_tmp $dir_met_tmp

# =============================================================================
# Convert WRF ensemble member forecast files to a format acceptable for MET
# =============================================================================

fcst_hour_padded=`printf "%02d" $fcst_hour`
if [[ "$fcst_lvl" == "Surface" ]]; then
  fname=surface_f${fcst_hour_padded}.nc
else
  fname=upper_f${fcst_hour_padded}.nc
fi

# Convert ensemble member forecasts to MET format
for mem in `seq 1 $NUM_MEM` ; do
  path_to_file=${dir_post}/${experiment}/${date_init}/${fname}

  if [[ -e "${path_to_file}" ]]; then

    cat > ${dir_tmp}/run_convert_to_met.bash << END_INPUT

    singularity exec ${met_container} pcp_combine -name ${fcst_key} -add PYTHON_NUMPY \
    'name="${dir_scripts}/convert_to_met.py ${path_to_file} ${fcst_key} ${fcst_lvl} ${mem} \
    ";' ${dir_tmp}/met_mem${mem}.nc

END_INPUT

    chmod u+x ${dir_tmp}/run_convert_to_met.bash
    ${dir_tmp}/run_convert_to_met.bash

    if [[ $? -ne 0 ]]; then
      echo "*** Error: convert_to_met.py returned a nonzero exit code. Skipping ${path_to_file} ..."
    fi

  else
    echo "*** Error: Could not find file ${path_to_file}, skipping..."
  fi
done

# =============================================================================
# Convert MADIS observation files to a format acceptable for MET
# =============================================================================

if [ ! -e "${dir_work}/obs/${date_fcst}/${obs_type}_${date_fcst}.nc" ] ; then
  echo 'Converting observation file '${dir_work}/obs/${date_fcst}/${obs_type}_${date_fcst}' to MET format'
  singularity exec ${met_container} madis2nc \
  ${dir_work}/obs/${date_fcst}/${obs_type}_${date_fcst} \
  ${dir_work}/obs/${date_fcst}/${obs_type}_${date_fcst}.nc -type $obs_type
fi
echo

# =============================================================================
# Run ensemble_stat
# =============================================================================

# Create the list of ensemble files to be verified, and count the ensemble members used
mem_count=0
for mem in `seq 1 $NUM_MEM` ; do
  fname=${dir_tmp}/met_mem${mem}.nc

  if [[ -e "$fname" ]]; then
    mem_count=$(( $mem_count + 1 ))
  	echo ${dir_tmp}/met_mem${mem}.nc >> ${dir_tmp}/ens_file_list
  fi
done

# Create a script to run a couple commands within the singularity container:
# 1) Set an environment variable specifying a path to an observation error file
# 2) Run ensemble_stat

if [[ "$obs_key" == "DPT" ]] && [[ "$obs_type" == "raob" ]]; then
  obspath=${dir_work}/obs/${date_fcst}/dewpoint_${date_fcst}.nc
else
  obspath=${dir_work}/obs/${date_fcst}/${obs_type}_${date_fcst}.nc
fi

cat > ${dir_tmp}/run_met.bash << END_INPUT

#!/bin/bash

export MET_OBS_ERROR_TABLE=${dir_scripts}/obs_error_table_FMH.txt
ensemble_stat ${dir_tmp}/ens_file_list \
${dir_tmp}/EnsembleStatConfig \
-point_obs ${obspath} \
-outdir ${dir_tmp}

END_INPUT

chmod u+x ${dir_tmp}/run_met.bash
echo 'Running MET ensemble_stat...'
singularity exec ${met_container} ${dir_tmp}/run_met.bash

fyear=`echo $date_fcst | cut -b1-4`
fmonth=`echo $date_fcst | cut -b5-6`
fday=`echo $date_fcst | cut -b7-8`
fhour=`echo $date_fcst | cut -b9-10`

mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V.stat \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}.stat
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_ens.nc \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_ens.nc
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_ecnt.txt \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_ecnt.txt
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_orank.txt \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_orank.txt
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_phist.txt \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_phist.txt
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_relp.txt \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_relp.txt
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_rhist.txt \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_rhist.txt
mv ${dir_tmp}/ensemble_stat_${fyear}${fmonth}${fday}_${fhour}0000V_ssvar.txt \
${dir_init}/ensemble_stat_d0${domain}_${fcst_key}_${fcst_lvl}_f${fcst_hour}_ssvar.txt

# Clean up intermediate files
rm -f ${dir_tmp}/*
rmdir ${dir_tmp}
