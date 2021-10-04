import sys
import os
from datetime import datetime, timedelta

import numpy as np
import xarray as xr

path = str(sys.argv[1])
name = str(sys.argv[2])
level = str(sys.argv[3])
member = int(sys.argv[4])

path_wrfref = os.getenv("PATH_WRFREF")

f = xr.open_dataset(path).squeeze()

initialization = datetime.strptime(f.initialization, "%Y-%m-%d %H:%M:%S")
forecast_hour = int(f.forecast_hour)
valid = initialization + timedelta(hours=forecast_hour)
domain = int(f.domain)

ref = xr.open_dataset("{}/wrfoutREFd0{}".format(path_wrfref, domain)).squeeze()

if level == "Surface":
    sel = {"member": member}
else:
    sel = {"member": member, "pressure": int(level)}

# Extract the forecast field from the dataset, convert to *DOUBLE* floating point
# precision (float64) as required by MET, and round to avoid adding random noise.
try:
    fcst_field = np.asarray(f[name].sel(sel), dtype=float).round(5)
    met_data = np.flip(fcst_field, axis=0).copy()
except KeyError as err:
    sys.stderr.write("{}: KeyError: {}".format(sys.argv[0], err))
    sys.exit(1)

# =====
# Create attributes dictionary as specified in MET user's guide under Python embedding
# =====

try:
    xlat = ref.variables['XLAT'].data
except KeyError:
    sys.stderr.write("{}: KeyError: {}".format(sys.argv[0], varkey))
    sys.exit(1)
try:
    xlong = ref.variables['XLONG'].data
except KeyError:
    sys.stderr.write("{}: KeyError: {}".format(sys.argv[0], varkey))
    sys.exit(1)

grid_attrs = {
    'type': 'Lambert Conformal',
    'hemisphere': 'N',
    'name': 'TTU WRF',
    'lat_pin': float(xlat[0, 0]),
    'lon_pin': float(xlong[0, 0]),
    'x_pin': 0.0,
    'y_pin': 0.0,
    'r_km': 6371.2,
    'scale_lat_1': float(ref.attrs['TRUELAT1']),
    'scale_lat_2': float(ref.attrs['TRUELAT2']),
    'lon_orient': float(ref.attrs['STAND_LON']),
    'd_km': float(ref.attrs['DX']) / 1000.,
    'nx': int(ref.attrs['WEST-EAST_GRID_DIMENSION']),
    'ny': int(ref.attrs['SOUTH-NORTH_GRID_DIMENSION']),
}

attrs = {
    'valid': valid.strftime("%Y%m%d_%H"),
    'init': initialization.strftime("%Y%m%d_%H"),
    'lead': str(forecast_hour),
    'accum': '0',
    'name': name,
    'long_name': name,
    'level': level,
    'units': str(f[name].units),
    'grid': grid_attrs,
}
