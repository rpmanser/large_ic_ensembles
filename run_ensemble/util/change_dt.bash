# ============================================================================================
# change_dt.bash
#
# Change the time step in a namelist.input file for a WRF simulation
#
# Parameters
# ----------
#   $1 = old_dt : current time step
#   $2 = new_dt : desired time step
#   $3 = path : Absolute path to namelist.input file to change
# ============================================================================================

old_dt=$1
new_dt=$2
path=$3

sed -i "s/ time_step  *= $old_dt,/ time_step = $new_dt,/" $path
