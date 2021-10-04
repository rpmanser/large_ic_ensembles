#!/bin/bash

########################################################################
# WRF_param_realtime_ens.bash
#
# Parameter file for replicating TTU WRF real-time ensemble settings.
########################################################################

username=rmanser
dir_base=/home/${username}/ic_ensembles

#  Domain-Specific Parameters
#*************************************************

let model_Nx1=390           # number of grid points in x-direction
let model_Ny1=328           # number of grid points in y-direction
let model_Nz=38             # number of grid points in vertical
let model_ptop=5000         # Pressure at model top
let model_gridspx1=12000    # gridspacing in x (in meters!!!)
let model_gridspy1=12000    # gridspacing in y
let dt=72                   # model time step (in sec)
model_centlat=38.           # center latitude of domain
model_centlon=-98.          # center longitude of domain
model_stdlat1=30.           # first true latitude of domain
model_stdlat2=60.           # second true latitude of domain
model_stdlon=-101.          # standard longitude
let dlbc=360                # number of minutes in between global model BCs
output_interval=60          # Frequency of model output to file - 12km
output_interval_4km=60      # Frequency of model output to file - 4km
model_num_in_output=1       # Output times per file
fct_len=2880                # Minutes to forecast for

# Nested domain info
#*************************************************
let model_gridspx1_4km=4000
let model_gridspy1_4km=4000
iparent_st_4km=112
jparent_st_4km=45
model_Nx1_4km=589
model_Ny1_4km=541
parent_id_4km=1
grid_ratio_4km=3

#  Locations of important directories
#*************************************************

dir_wps=/lustre/work/${username}/WPSV3.5.1              # WPS location
dir_wrf=/lustre/work/${username}/WRFV3.5.1/run          # WRF location
dir_wrfvar=/lustre/work/${username}/WRFDAV3.5.1serial   # WRFVAR location

# Location of TTU WRF EnKF files
dir_enkf_research=/lustre/research/bancell/SE2016
dir_enkf_work=/lustre/research/bancell/SE2016-FromWork
dir_enkf_scratch=/lustre/old-scratch/bancell/SE2016
# Initialization dates corresponding to the above paths
date_research=2016051512
date_work=2016052312
date_scratch=2016060312

dir_scratch=/lustre/scratch/${username}
dir_work=/lustre/work/${username}
dir_research=/lustre/research/bancell/${username}
dir_log=${dir_base}/log                              # log directory
#dir_store=/lustre/work/bancell/longsave             # storage directory

# Parameters for the model (not changed very often)
#**************************************************
model_mp_phys=8          # microphysics scheme
let model_spec_zone=1    # number of grid points with tendencies
let model_relax_zone=4   # number of blended grid points
dodfi=0                  # Do Dfi 3-yes 0-no
model_lw_phys=1          # model long wave scheme
model_sw_phys=1          # model short wave scheme
model_radt=30            # radiation time step (in minutes)
model_sfclay_phys=1      # surface layer physics
model_surf_phys=2        # land surface model
model_pbl_phys=1         # pbl physics
model_bldt=0             # boundary layer time steps (0 : each time steps, in min)
model_cu_phys=6          # cumulus param
model_cu_phys_4km=0      # cumulus param 4km
model_cudt=5             # cumuls time step
model_use_surf_flux=1    # 1 is yes
model_use_snow=1
model_use_cloud=1
model_soil_layers=4
model_w_damping=1
model_diff_opt=1
model_km_opt=4
model_dampcoef=0.2
model_tbase=300.

#************************************
# Calculated terms

let time_step='(fct_len*60)/dt'
let fct_len_hrs='fct_len/60'
let dlbc_hrs='dlbc/60'
let assim_bzw='model_spec_zone+model_relax_zone'
let otime='output_interval_4km/60'
