# calc_stage4_nps.py

import os
import argparse
from pathlib import Path

import xarray as xr
import numpy as np
import pandas as pd
from metpy.units import units

import neighborhood

parser = argparse.ArgumentParser(
    description='Calculate hourly neighborhood probabilities from column maximum reflectivity'
)
parser.add_argument('date_str', type=str, help='Date formatted as YYYYMMDDHH')

args = parser.parse_args()
date = pd.to_datetime(args.date_str, format="%Y%m%d%H")

radii = (np.array([20., 40., 60.]) * units.mile).to("meter")
thresholds = (np.array([0.01, 0.1, 0.25, 0.5, 1.0]) * units.inch).to("millimeter")

wrfref = xr.open_dataset(Path(os.getenv("PATH_WRFREF")) / "wrfoutREFd02")
st4 = xr.open_dataset(Path(os.getenv("PATH_STAGE4_OBS")) / f'ST4.{date.strftime("%Y%m%d%H")}.01h.nc')

obs_x, obs_y, wrf_x, wrf_y, obs_mask = neighborhood.subset_to_forecast_grid(wrfref, st4.longitude, st4.latitude, return_mask=True)
points = np.vstack((obs_y, obs_x)).T
xi = np.vstack((wrf_y.flatten(), wrf_x.flatten())).T

thresh_probs = {}
for thresh in thresholds:
    obs_probs = np.full((radii.size, *wrf_x.shape), np.nan, dtype=float)

    probs_bin = st4.tp.values.copy()
    thresh_field = (st4.tp.values >= thresh.m)
    probs_bin[thresh_field] = 1.
    probs_bin[~thresh_field] = 0.
    values = probs_bin[obs_mask]

    for i, r in enumerate(radii):
        query = neighborhood.build_query(points, xi, r)

        probs = neighborhood.neighbor_prob(xi, values, query)
        probs.shape = wrf_x.shape
        probs[np.where(np.isnan(probs))] = 0.
        obs_probs[i] = probs * 100.

    thresh_str = (
        'precipitation_'
        f'{str(thresh.m).replace(".", "_").strip("_").replace("_0", "")}'
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
    key: (dims, value, {'threshold': str(t)})
    for (key, value), t in zip(thresh_probs.items(), thresholds)
}

ds = xr.Dataset(data, coords)
path_out = Path(os.getenv("PATH_STAGE4_SAVE"))
ds.to_netcdf(path_out / f'stage4_{date.strftime("%Y%m%d%H")}.nc')
