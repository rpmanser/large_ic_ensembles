#!/bin/bash
# ============================================================================================
# make_namelist_updatebc.bash
#
# Creates wrfvar parame.in file then updates lateral boundary conditions for a
# parent domain (d01) from a WRF IC file called wrfvar_output.
#
# Parameters
# ----------
#   $1 = dir_wrfvar : absolute directory path to WRFVAR directory containing ICs/BCs
# ============================================================================================

dir_wrfvar=$1

cat > ${dir_wrfvar}/parame.in << END_INPUT

&control_param
 da_file            = './wrfvar_output'
 wrf_bdy_file       = './wrfbdy_d01'
 domain_id          = 1
 debug              = .true.
 update_lateral_bdy = .true.
 update_low_bdy     = .false.
 update_lsm         = .false.
 iswater            = 16
 var4d_lbc          = .false.
/

END_INPUT
