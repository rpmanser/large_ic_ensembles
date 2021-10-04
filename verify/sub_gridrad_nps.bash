#!/bin/sh
#SBATCH -D ./
#SBATCH -J gr_neps
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err
#SBATCH -p quanah
#SBATCH --nodes=1
#SBATCH --ntasks=24
#SBATCH -a 1-1:1

# ============================================================================================
# sub_gridrad_nps.bash
#
# Create neighborhood probabilities from column maximum GridRad reflectivity observations.
#
# 24 hours are processed at a time, which takes roughly 24 hours of compute
# time with 24 cores. This is mostly due to processing the 96 km neighborhood.
#
# Parameters
# ----------
#   None
# ============================================================================================

PATH_GRIDRAD_OBS=/lustre/work/rmanser/gridrad
PATH_WRFREF=/lustre/work/rmanser/wrfref
PATH_GRIDRAD_SAVE=/lustre/scratch/rmanser/gr_nps
export PATH_GRIDRAD_OBS=$PATH_GRIDRAD_OBS
export PATH_WRFREF=$PATH_WRFREF
export PATH_GRIDRAD_SAVE=$PATH_GRIDRAD_SAVE

dir_base=/home/rmanser/ic_ensembles

source activate ens
pyenv=`which python`

DATE_BEGIN=2016042700

let hours='SLURM_ARRAY_TASK_ID * 24 - 24'
date=`python ${dir_base}/modify_date.py $DATE_BEGIN $hours`

if [[ "$date" == "2016060500" ]]; then
  dt=12
else
  dt=24
fi

# end=`python ${dir_base}/modify_date.py $date $dt`
end=2016042701

echo "Creating NPs from column maximum GridRad reflectivity for $date to $end"
mkdir -p $PATH_GRIDRAD_SAVE

while [[ $date -lt $end ]]; do
  echo "Working on date $date..."
  $pyenv -u ${dir_base}/verify/calc_gridrad_nps.py $date
  if [[ $? -ne 0 ]]; then
    echo "Python script exited with nonzero code. Exiting..."
    exit
  fi
  date=`python ${dir_base}/modify_date.py $date 1`
done
