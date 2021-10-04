#!/bin/bash
#######################################################################
# make_namelist_wrf_downscale.bash
#
# Create a WRF namelist.input file for a downscaled GEFS ensemble member forecast.
#
# The number of metgrid levels in GEFS output is 17.
# The number of soil levels in GEFS output is 3.
#
# Parameters
# ----------
#   $1 = param : parameter file
#   $2 = date_begin : start date of model
#   $3 = date_end : end date of model
#   $4 = dir_wrf : wrf member directory
#######################################################################

param=$1
date_begin=$2
date_end=$3
source $param

# Override the parameter file's path to the wrf directory
dir_wrf=$4

date_prior=`python ${dir_base}/modify_date.py $date_begin 1`

model_START_YEAR=${date_begin:0:4}
model_START_MONTH=${date_begin:4:2}
model_START_DAY=${date_begin:6:2}
model_START_HOUR=${date_begin:8:2}
model_START_MINUTE=00
model_START_SECOND=00
model_END_YEAR=${date_end:0:4}
model_END_MONTH=${date_end:4:2}
model_END_DAY=${date_end:6:2}
model_END_HOUR=${date_end:8:2}
model_END_MINUTE=00
model_END_SECOND=00
let model_BC_INTERVAL='dlbc*60'
model_RUN_MINUTES=$fct_len

model_START_YEARdfi=${date_prior:0:4}
model_START_MONTHdfi=${date_prior:4:2}
model_START_DAYdfi=${date_prior:6:2}
model_START_HOURdfi=${date_prior:8:2}
model_START_MINUTEdfi=30
model_START_SECONDdfi=00

rm -f ${dir_wrf}/namelist.input

cat > ${dir_wrf}/namelist.input << END_INPUT

&time_control
 run_days                            = 0,
 run_hours                           = 0,
 run_minutes                         = $model_RUN_MINUTES,
 run_seconds                         = 0,
 start_year                          = $model_START_YEAR, $model_START_YEAR,
 start_month                         = $model_START_MONTH, $model_START_MONTH,
 start_day                           = $model_START_DAY, $model_START_DAY,
 start_hour                          = $model_START_HOUR, $model_START_HOUR,
 start_minute                        = $model_START_MINUTE, $model_START_MINUTE,
 start_second                        = $model_START_SECOND, $model_START_SECOND,
 end_year                            = $model_END_YEAR, $model_END_YEAR,
 end_month                           = $model_END_MONTH, $model_END_MONTH,
 end_day                             = $model_END_DAY, $model_END_DAY,
 end_hour                            = $model_END_HOUR, $model_END_HOUR,
 end_minute                          = $model_END_MINUTE, $model_END_MINUTE,
 end_second                          = $model_END_SECOND, $model_END_SECOND,
 interval_seconds                    = $model_BC_INTERVAL
 input_from_file                     = .true.,.true.,
 history_interval                    = $output_interval, $output_interval_4km,
 frames_per_outfile                  = $model_num_in_output, $model_num_in_output,
 restart                             = .false.,
 restart_interval                    = 5000,
 io_form_history                     = 2
 io_form_restart                     = 2
 io_form_input                       = 2
 io_form_boundary                    = 2
 debug_level                         = 0
 nwp_diagnostics		     = 1
 /

&domains
 time_step                           = $dt,
 time_step_fract_num                 = 0,
 time_step_fract_den                 = 1,
 max_dom                             = 2,
 e_we                                = $model_Nx1, $model_Nx1_4km,
 e_sn                                = $model_Ny1, $model_Ny1_4km,
 e_vert                              = $model_Nz,  $model_Nz,
 eta_levels			     = 1.000, 0.995, 0.990, 0.985,
                                       0.980, 0.970, 0.960, 0.950,
                                       0.940, 0.930, 0.920, 0.910,
                                       0.900, 0.880, 0.860, 0.830,
                                       0.800, 0.770, 0.740, 0.710,
                                       0.680, 0.640, 0.600, 0.560,
                                       0.520, 0.480, 0.440, 0.400,
                                       0.360, 0.320, 0.280, 0.240,
                                       0.200, 0.160, 0.120, 0.080,
                                       0.040, 0.000
 p_top_requested                     = $model_ptop,
 num_metgrid_levels                  = 17
 num_metgrid_soil_levels             = 3,
 dx                                  = $model_gridspx1, $model_gridspx1_4km,
 dy                                  = $model_gridspy1, $model_gridspy1_4km,
 grid_id                             = 1,     2,
 parent_id                           = 0,     1,
 i_parent_start                      = 1,  $iparent_st_4km,
 j_parent_start                      = 1,  $jparent_st_4km,
 parent_grid_ratio                   = 1, $grid_ratio_4km,
 parent_time_step_ratio              = 1, $grid_ratio_4km,
 feedback                            = 0,
 smooth_option                       = 0,
 /

&dfi_control
 dfi_opt                             = $dodfi,
 dfi_nfilter                         = 7,
 dfi_write_filtered_input            = .false.,
 dfi_write_dfi_history               = .false.,
 dfi_cutoff_seconds                  = 3600,
 dfi_time_dim                        = 1000,
 dfi_bckstop_year                    = $model_START_YEARdfi,
 dfi_bckstop_month                   = $model_START_MONTHdfi,
 dfi_bckstop_day                     = $model_START_DAYdfi,
 dfi_bckstop_hour                    = $model_START_HOURdfi,
 dfi_bckstop_minute                  = $model_START_MINUTEdfi,
 dfi_bckstop_second                  = $model_START_SECONDdfi,
 dfi_fwdstop_year                    = $model_START_YEAR,
 dfi_fwdstop_month                   = $model_START_MONTH,
 dfi_fwdstop_day                     = $model_START_DAY,
 dfi_fwdstop_hour                    = $model_START_HOUR,
 dfi_fwdstop_minute                  = $model_START_MINUTE,
 dfi_fwdstop_second                  = $model_START_SECOND,
 /

&physics
 mp_physics                          = $model_mp_phys, $model_mp_phys,
 ra_lw_physics                       = $model_lw_phys, $model_lw_phys,
 ra_sw_physics                       = $model_sw_phys, $model_sw_phys,
 radt                                = $model_radt,    $model_radt,
 sf_sfclay_physics                   = $model_sfclay_phys, $model_sfclay_phys,
 sf_surface_physics                  = $model_surf_phys, $model_surf_phys,
 bl_pbl_physics                      = $model_pbl_phys, $model_pbl_phys,
 bldt                                = $model_bldt, $model_bldt,
 cu_physics                          = $model_cu_phys, $model_cu_phys_4km,
 cudt                                = $model_cudt,
 isfflx                              = $model_use_surf_flux,
 ifsnow                              = $model_use_snow,
 icloud                              = $model_use_cloud,
 surface_input_source                = 1,
 num_soil_layers                     = $model_soil_layers,
 sf_urban_physics                    = 0,  0,
 maxiens                             = 1,
 maxens                              = 3,
 maxens2                             = 3,
 maxens3                             = 16,
 ensdim                              = 144,
 do_radar_ref			     = 1,
 /

&fdda
 /

 &dynamics
 w_damping                           = $model_w_damping,
 diff_opt                            = $model_diff_opt,
 km_opt                              = $model_km_opt,
 diff_6th_opt                        = 0,
 diff_6th_factor                     = 0.12,
 base_temp                           = $model_tbase,
 damp_opt                            = 0,
 zdamp                               = 5000.,  5000.,
 dampcoef                            = $model_dampcoef, $model_dampcoef,
 khdif                               = 0,      0,
 kvdif                               = 0,      0,
 non_hydrostatic                     = .true., .true.,
 moist_adv_opt                       = 1,      1,
 scalar_adv_opt                      = 1,      1,
 /

&bdy_control
 spec_bdy_width                      = $assim_bzw,
 spec_zone                           = $model_spec_zone,
 relax_zone                          = $model_relax_zone,
 specified                           = .true., .false.,
 nested                              = .false., .true.,
 /

&grib2
 /

&namelist_quilt
 nio_tasks_per_group = 0,
 nio_groups = 1,
 /
END_INPUT
