#!/bin/bash
#######################################################################
# make_namelist_wps_GFS.bash
#
# Create a WPS namelist for GFS ICs.
#
# Parameters
# ----------
#   $1 = param : parameter file
#   $2 = date_begin : start date of model
#   $3 = date_end : end date of model
#   $4 = dir_wps : ensemble member WPS directory
#
# Authors: B. C. Ancell, R. P. Manser
#######################################################################

param=$1
date_begin=$2
date_end=$3
source $param

# Override the parameter file's path to the wps directory
dir_wps=$4

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

rm -f ${dir_wps}/namelist.wps

cat > ${dir_wps}/namelist.wps << END_INPUT

&share
 wrf_core = 'ARW',
 max_dom = 2,
 start_date = '${model_START_YEAR}-${model_START_MONTH}-${model_START_DAY}_${model_START_HOUR}:00:00','${model_START_YEAR}-${model_START_MONTH}-${model_START_DAY}_${model_START_HOUR}:00:00',
 end_date   = '${model_END_YEAR}-${model_END_MONTH}-${model_END_DAY}_${model_END_HOUR}:00:00','${model_END_YEAR}-${model_END_MONTH}-${model_END_DAY}_${model_END_HOUR}:00:00',
 interval_seconds = ${model_BC_INTERVAL}
 io_form_geogrid = 2,
/

&geogrid
 parent_id         =   0, ${parent_id_4km},
 parent_grid_ratio =   1, ${grid_ratio_4km},
 i_parent_start    =   1,  ${iparent_st_4km},
 j_parent_start    =   1,  ${jparent_st_4km},
 e_we              =  ${model_Nx1}, ${model_Nx1_4km},
 e_sn              =  ${model_Ny1}, ${model_Ny1_4km},
 geog_data_res     = '30s','30s',
 dx = ${model_gridspx1},
 dy = ${model_gridspy1},
 map_proj = 'lambert',
 ref_lat   = ${model_centlat},
 ref_lon   = ${model_centlon},
 truelat1  = ${model_stdlat1},
 truelat2  = ${model_stdlat2} ,
 stand_lon = ${model_stdlon},
 geog_data_path = '/lustre/work/rmanser/geogV351'
/

&ungrib
 out_format = 'WPS',
 prefix = 'GFS',
/

&metgrid
 fg_name = 'FILE', 'GFS'
 io_form_metgrid = 2,
/
END_INPUT
