#!/bin/bash

###############################################################################
# make_EnsembleStatConfig.bash
#
# Create an EnsembleStatConfig file for the Model Evaluation Tools (MET) V8.0
# ensemble_stat command line program. Only fields that differ from the default
# values in /met_root/data/config/EnsembleStatConfig_default are changed.
#
# Parameters:
#   param - Parameter file describing relevant ensemble stat options
#   climo - boolean for whether or not TTU EnKF should be included as climatology mean (true of false)
#
# Created: 3/21/19
# Author: R. P. Manser
###############################################################################


param=$1
dir_tmp=$2
dir_met_tmp=$3
source $param

cat > ${dir_tmp}/EnsembleStatConfig << END_INPUT

////////////////////////////////////////////////////////////////////////////////
//
// Ensemble-Stat configuration file.
//
// For additional information, see the MET_BASE/config/README file.
//
////////////////////////////////////////////////////////////////////////////////

tmp_dir = "$dir_met_tmp";

////////////////////////////////////////////////////////////////////////////////

//
// Verification grid
// May be set separately in each "field" entry
//
regrid = {
   to_grid    = OBS;
   method     = BILIN;
   width      = 2;
   vld_thresh = 1.0;
   shape      = SQUARE;
}

////////////////////////////////////////////////////////////////////////////////

//
// Ensemble product fields to be processed
//
ens = {
   file_type = NETCDF_MET;
   ens_thresh = 0.95;
   vld_thresh = 1.0;

   field = [
     {
       name  = "${fcst_key}";
       level = [ "${fcst_lvl}" ];
       cat_thresh = [ ${cat_thresh} ];
     }
  ];
}

////////////////////////////////////////////////////////////////////////////////

//
// Forecast and observation fields to be verified
//
fcst = {
   file_type = NETCDF_MET;
   censor_thresh = [ ${censor_thresh} ];
   censor_val = [ ${censor_val} ];

   field = [
    {
      name  = "${fcst_key}";
      level = [ "${fcst_lvl}" ];
      cat_thresh = [ ${cat_thresh} ];
    }
  ];
}

obs = {
  file_type = NETCDF_MET;

  field = [
    {
      name = "${obs_key}";
      level = [ "${obs_lvl}" ];
      cat_thresh = [ ${cat_thresh} ];
    }
  ];
}


////////////////////////////////////////////////////////////////////////////////

//
// Point observation filtering options
// May be set separately in each "obs.field" entry
//
message_type   = [ "${msg_type}" ];
sid_exc        = [];
obs_thresh     = [ NA ];
obs_quality    = [];
duplicate_flag = NONE;
obs_summary    = NONE;
obs_perc_value = 50;
skip_const     = TRUE;

////////////////////////////////////////////////////////////////////////////////

//
// Interpolation methods
//
interp = {
   field      = FCST;
   vld_thresh = 1.0;
   shape  = SQUARE;

   type = [
      {
         method = BILIN;
         width  = 2;
      }
   ];
}


//
// Observation error options
// Set dist_type to NONE to use the observation error table instead
// May be set separately in each "obs.field" entry
//
obs_error = {
   flag             = TRUE;   // TRUE or FALSE
   dist_type        = ${dist_type};    // Distribution type
   dist_parm        = [ ${dist_param} ];      // Distribution parameters
   inst_bias_scale  = 0.0;     // Instrument bias scale adjustment
   inst_bias_offset = 0.0;     // Instrument bias offset adjustment
   min              = NA;      // Valid range of data
   max              = NA;
}

////////////////////////////////////////////////////////////////////////////////

//
// Statistical output types
//
output_flag = {
   ecnt  = BOTH;
   rhist = BOTH;
   phist = NONE;
   orank = BOTH;
   ssvar = BOTH;
   relp  = NONE;
}

////////////////////////////////////////////////////////////////////////////////

grid_weight_flag = NONE;
duplicate_flag = UNIQUE;
obs_summary = NEAREST;
output_prefix    = "";
version          = "V8.0";

////////////////////////////////////////////////////////////////////////////////

END_INPUT
