# =============================================================================
# calc_gridrad_neps.py
#
# Calculate neighborhood probabilitieas from gridrad reflectivity for a single date and time.
#
# Author: R. P. Manser
# Date created: 12/15/20
# =============================================================================

import os
import argparse
from datetime import datetime
from pathlib import Path

import numpy as np
import xarray as xr
from metpy.units import units

import gridrad
import neighborhood
from wrf_ens_tools.calc import coordinateSystems

parser = argparse.ArgumentParser(
    description='Calculate hourly neighborhood probabilities from column maximum reflectivity'
)
parser.add_argument('date_str', type=str, help='Date formatted as YYYYMMDDHH')

args = parser.parse_args()
date_str = args.date_str

date = datetime.strptime(date_str, "%Y%m%d%H")

path_ref = Path(os.getenv("PATH_WRFREF")) / 'wrfoutREFd02'
path_save = Path(os.getenv("PATH_GRIDRAD_SAVE")) / f'gridrad_{date.strftime("%Y%m%d%H")}.nc'

path_gr = Path(os.getenv("PATH_GRIDRAD_OBS")) / date.strftime("%Y%m")
path_file = path_gr / f'nexrad_3d_v3_1_{date.strftime("%Y%m%dT%H%M%S")}Z.nc'

gr_raw = gridrad.read_file(path_file)

if type(gr_raw) is int:
    sys.stderr.write(f"Could not find observation file {path_file} to build grid. Exiting...")
    sys.exit(gr_raw)

grlon = gr_raw['x']['values']
grlat = gr_raw['y']['values']
grlongrid, grlatgrid = np.meshgrid(grlon, grlat)

wrfref = xr.open_dataset(path_ref)

obs_x, obs_y, wrf_x, wrf_y, obs_mask = neighborhood.subset_to_forecast_grid(
    wrfref,
    grlongrid,
    grlatgrid,
    return_mask=True
)

points = np.vstack((obs_y, obs_x)).T
xi = np.vstack((wrf_y.flatten(), wrf_x.flatten())).T

radii = (np.array([20., 40., 60.]) * units.mile).to('meter')
thresholds = np.array([25., 40.])
thresh_probs = {}
for thresh in thresholds:
    obs_probs = np.full((radii.size, *wrf_x.shape), -1., dtype=float)

    comp_refl = neighborhood.open_rad_obs(path_file, level='colmax')
    comp_refl_bin = comp_refl.copy()
    thresh_field = (comp_refl >= thresh)
    comp_refl_bin[thresh_field] = 1.
    comp_refl_bin[~thresh_field] = 0.
    values = comp_refl_bin[obs_mask]

    for i, r in enumerate(radii):
        query = neighborhood.build_query(points, xi, r)

        probs = neighborhood.neighbor_prob(xi, values, query)
        probs.shape = wrf_x.shape
        probs[np.where(np.isnan(probs))] = 0.
        obs_probs[i] = probs * 100.

    thresh_str = (
        'col_max_refl_'
        f'{str(thresh).replace(".", "_").strip("_").replace("_0", "")}'
    )
    thresh_probs[thresh_str] = obs_probs

# Write results to file
nx, ny = wrf_x.shape
x = np.arange(1, nx)
y = np.arange(1, ny)
radii = radii.to('kilometer')

dims = ['radii', 'y', 'x']
coords = {
    'radius': (['radii'], radii.m, {'units': str(radii.units)})
}
data = {
    key: (dims, value, {'threshold': t})
    for (key, value), t in zip(thresh_probs.items(), thresholds)
}

ds = xr.Dataset(data, coords)
ds.to_netcdf(path_save)
