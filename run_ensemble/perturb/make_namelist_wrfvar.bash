#!/bin/bash
# ============================================================================================
# make_namelist_wrfvar.bash
#
# Create a namelist for WRFVAR that generates ensemble members by perturbing
# around an analysis. This is done using the RANDOMCV capability.
#
# Perturbations are applied randomly with fixed seeds specified as the initialization
# date and ensemble member number. The same random perturbations will be applied
# for the same seeds.
#
# Parameters
# ----------
#   $1 = param : parameter file containing paths and WRF namelist variables
#   $2 = init : forecast initialization date (YYYYMMDDHH)
#   $3 = mem : ensemble member number (to seed random perturbations)
#   $4 = dir_wrfda : absolute path to wrfvar ensemble member directory
# ============================================================================================

param=$1
init=$2
mem=$3
source $param
dir_wrfda=$4

date_prior=`python ${dir_base}/modify_date.py $init -3`
date_final=`python ${dir_base}/modify_date.py $init 3`

model_START_YEAR=${init:0:4}
model_START_MONTH=${init:4:2}
model_START_DAY=${init:6:2}
model_START_HOUR=${init:8:2}
model_START_MINUTE=00
model_START_SECOND=00
let model_BC_INTERVAL='dlbc*60'
model_RUN_MINUTES=$fct_len

model_START_YEARdfi=${date_prior:0:4}
model_START_MONTHdfi=${date_prior:4:2}
model_START_DAYdfi=${date_prior:6:2}
model_START_HOURdfi=${date_prior:8:2}
model_START_MINUTEdfi=30
model_START_SECONDdfi=00

ANALYSIS_DATE=${init:0:4}-${init:4:2}-${init:6:2}_${init:8:2}:00:00.0000
TIME_WINDOW_MIN=${date_prior:0:4}-${date_prior:4:2}-${date_prior:6:2}_${date_prior:8:2}:00:00.0000
TIME_WINDOW_MAX=${date_final:0:4}-${date_final:4:2}-${date_final:6:2}_${date_final:8:2}:00:00.0000

rm -f ${dir_wrfda}/namelist.input

cat > ${dir_wrfda}/namelist.input << END_INPUT
&wrfvar1
/
&wrfvar2
/
&wrfvar3
/
&wrfvar4
/
&wrfvar5
put_rand_seed=true,
/
&wrfvar6
max_ext_its=1,
ntmax=200,
orthonorm_gradient=true,
/
&wrfvar7
cv_options=3,
as1 = 0.25, 1.00, 1.50,
as2 = 0.25, 1.00, 1.50,
as3 = 0.25, 1.00, 1.50,
as4 = 0.25, 1.00, 1.50,
as5 = 0.20, 1.00, 1.50,
/
&wrfvar8
/
&wrfvar9
/
&wrfvar10
/
&wrfvar11
seed_array1 = ${init},
seed_array2 = ${mem},
/
&wrfvar12
/
&wrfvar13
/
&wrfvar14
/
&wrfvar15
/
&wrfvar16
/
&wrfvar17
analysis_type="RANDOMCV"
/
&wrfvar18
analysis_date="$ANALYSIS_DATE",
/
&wrfvar19
/
&wrfvar20
/
&wrfvar21
time_window_min="$TIME_WINDOW_MIN",
/
&wrfvar22
time_window_max="$TIME_WINDOW_MAX",
/
&wrfvar23
/
&time_control
start_year                          = $model_START_YEAR,
start_month                         = $model_START_MONTH,
start_day                           = $model_START_DAY,
start_hour                          = $model_START_HOUR,
end_year                            = $model_START_YEAR,
end_month                           = $model_START_MONTH,
end_day                             = $model_START_DAY,
end_hour                            = $model_START_HOUR,
/

&domains
 e_we                                = $model_Nx1,
 e_sn                                = $model_Ny1,
 e_vert                              = $model_Nz,
 dx                                  = $model_gridspx1,
 dy                                  = $model_gridspy1,
 i_parent_start                      = 1,
 j_parent_start                      = 1,
 /


&dfi_control
/

&physics
 mp_physics                          = $model_mp_phys,
 ra_lw_physics                       = $model_lw_phys,
 ra_sw_physics                       = $model_sw_phys,
 radt                                = $model_radt,
 sf_sfclay_physics                   = $model_sfclay_phys,
 sf_surface_physics                  = $model_surf_phys,
 bl_pbl_physics                      = $model_pbl_phys,
 cu_physics                          = $model_cu_phys,
 cudt                                = $model_cudt,
 num_soil_layers                     = $model_soil_layers,
 mp_zero_out                         = 2,
 co2tf                               = 0,
 /

&fdda
 /

&dynamics
 /

&bdy_control
 /

&grib2
 /

&namelist_quilt
 /
END_INPUT
