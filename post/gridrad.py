# +
# Name:
# 		GRIDRAD Python Module
# Purpose:
# 		This module contains three functions for dealing with Gridded NEXRAD WSR-88D Radar
# 		(GridRad) data: reading (read_file), filtering (filter), and decluttering (remove_clutter).
# Author and history:
# 		Cameron R. Homeyer  2017-07-03.
# 		Edited: Russell P. Manser 2020-04-02
# Warning:
# 		The authors' primary coding language is not Python. This code works, but may not be
#      the most efficient or proper approach. Please suggest improvements by sending an email
# 		 to chomeyer@ou.edu.
# -
# Original file can be found at: http://gridrad.org/software.html

import os

import matplotlib.pyplot as plt
import numpy as np
import xarray as xr


# GridRad read routine
def read_file(infile):
    """Read a GridRad file and return data as a dictionary.

    Parameters
    ----------
    infile : str or os.path object
        Path to GridRad netCDF file

    Returns
    -------
    dict
        Python dictionary containing data and its attributes
    """

    # Check to see if file exists
    if not os.path.isfile(infile):
        print('File "' + infile + '" does not exist.  Returning -2.')
        return -2

    # Check to see if file has size of zero
    if os.stat(infile).st_size == 0:
        print('File "' + infile + '" contains no valid data.  Returning -1.')
        return -1

    # Open GridRad netCDF file
    id = xr.open_dataset(infile, backend_kwargs={"clobber": False})

    # Read list of merged files
    # NOTE: this does not retain the original behavior!
    files_merged = id.files_merged.values

    # Read dimensions
    x = {"values": id.Longitude.values}
    x.update(id.Longitude.attrs)
    x.update({"n": len(x["values"])})
    y = {"values": id.Latitude.values}
    y.update(id.Latitude.attrs)
    y.update({"n": len(y["values"])})
    z = {"values": id.Altitude.values}
    z.update(id.Altitude.attrs)
    z.update({"n": len(z["values"])})

    # Read observation and echo counts
    nobs = id.Nradobs
    necho = id.Nradecho
    index = id.index

    # Read reflectivity variables
    Z_H = id.Reflectivity
    wZ_H = id.wReflectivity

    # Create arrays to store binned values
    grid_shape = (z["values"].shape[0], y["values"].shape[0], x["values"].shape[0])
    values = np.full(grid_shape[0] * grid_shape[1] * grid_shape[2], np.nan)
    wvalues = values.copy()

    # Add values to arrays
    values[index] = Z_H
    wvalues[index] = wZ_H

    # Reshape arrays to 3-D GridRad domain
    values = values.reshape(grid_shape)
    wvalues = wvalues.reshape(grid_shape)

    Z_H = {
        "values": values,
        "long_name": str(Z_H.long_name),
        "units": str(Z_H.units),
        "missing": np.nan,
        "wvalues": wvalues,
        "wlong_name": str(wZ_H.long_name),
        "wunits": str(wZ_H.units),
        "wmissing": np.nan,
        "n": values.size,
    }

    # Close netCDF4 file
    id.close()

    # Return data dictionary
    data = {
        "name": "GridRad analysis for " + id.Analysis_time,
        "x": x,
        "y": y,
        "z": z,
        "Z_H": Z_H,
        "nobs": nobs.values,
        "necho": necho.values,
        "file": str(infile),
        "files_merged": files_merged,
    }
    data.update(id.attrs)
    return data


# GridRad filter routine
def filter(data0):
    """Filter GridRad data

    Parameters
    ----------
    data0 : dict
        Dictionary of GridRad data and attributes.

    Returns
    -------
    dict
        Dictionary with the same structure as data0, but containing filtered data
        and unmodified attributes.
    """
    year = float((data0["Analysis_time"])[0:4])

    wmin = (
        0.1  # Set absolute minimum weight threshold for an observation (dimensionless)
    )
    wthresh = 1.33 - 1.0 * (
        year < 2009
    )  # Set default bin weight threshold for filtering by year (dimensionless)
    freq_thresh = 0.6  # Set echo frequency threshold (dimensionless)
    Z_H_thresh = 18.5  # Reflectivity threshold (dBZ)
    nobs_thresh = 2  # Number of observations threshold

    # Extract dimension sizes
    nx = (data0["x"])["n"]
    ny = (data0["y"])["n"]
    nz = (data0["z"])["n"]

    echo_frequency = np.zeros(
        (nz, ny, nx)
    )  # Create array to compute frequency of radar obs in grid volume with echo

    ipos = np.where(data0["nobs"] > 0)  # Find bins with obs
    npos = len(ipos[0])  # Count number of bins with obs

    if npos > 0:
        echo_frequency[ipos] = (data0["necho"])[ipos] / (data0["nobs"])[
            ipos
        ]  # Compute echo frequency (number of scans with echo out of total number of scans)

    inan = np.where(np.isnan((data0["Z_H"])["values"]))  # Find bins with NaNs
    nnan = len(inan[0])  # Count number of bins with NaNs

    if nnan > 0:
        ((data0["Z_H"])["values"])[inan] = 0.0

    # Find observations with low weight
    ifilter = np.where(
        ((data0["Z_H"])["wvalues"] < wmin)
        | (
            ((data0["Z_H"])["wvalues"] < wthresh)
            & ((data0["Z_H"])["values"] <= Z_H_thresh)
        )
        | ((echo_frequency < freq_thresh) & (data0["nobs"] > nobs_thresh))
    )

    nfilter = len(ifilter[0])  # Count number of bins that need to be removed

    # Remove low confidence observations
    if nfilter > 0:
        ((data0["Z_H"])["values"])[ifilter] = float("nan")

    # Replace NaNs that were previously removed
    if nnan > 0:
        ((data0["Z_H"])["values"])[inan] = float("nan")

    # Return filtered data0
    return data0


def remove_clutter(data0, **kwargs):
    """Remove reflectivity clutter from GridRad data.

    Parameters
    ----------
    data0 : dict
        Dictionary of GridRad data and attributes.
    skip_weak_ll_echo : int (default=0)
        Whether or not to remove reflectivity values from low-level scatterers.
        0 denotes that low-level scatterers will be removed. Any other integer value
        denotes skipping this process.

    Returns
    -------
    dict
        Dictionary with the same structure as data0, but containing data without
        ground clutter.
    """
    if "skip_weak_ll_echo" not in kwargs:
        skip_weak_ll_echo = 0

    # Set fractional areal coverage threshold for speckle identification
    areal_coverage_thresh = 0.32

    # Extract dimension sizes
    nx = (data0["x"])["n"]
    ny = (data0["y"])["n"]
    nz = (data0["z"])["n"]

    # Copy altitude array to 3 dimensions
    zzz = ((((data0["z"])["values"]).reshape(nz, 1, 1)).repeat(ny, axis=1)).repeat(
        nx, axis=2
    )

    # First pass at removing speckles
    fin = np.isfinite((data0["Z_H"])["values"])

    # Compute fraction of neighboring points with echo
    cover = np.zeros((nz, ny, nx))
    for i in range(-2, 3):
        for j in range(-2, 3):
            cover += np.roll(np.roll(fin, i, axis=2), j, axis=1)
    cover = cover / 25.0

    # Find bins with low nearby areal echo coverage (i.e., speckles) and remove (set to NaN).
    ibad = np.where(cover <= areal_coverage_thresh)
    nbad = len(ibad[0])
    if nbad > 0:
        ((data0["Z_H"])["values"])[ibad] = float("nan")

    # Attempts to mitigate ground clutter and biological scatterers
    if skip_weak_ll_echo == 0:
        # First check for weak, low-level echo
        inan = np.where(np.isnan((data0["Z_H"])["values"]))  # Find bins with NaNs
        nnan = len(inan[0])  # Count number of bins with NaNs

        if nnan > 0:
            ((data0["Z_H"])["values"])[inan] = 0.0

        # Find weak low-level echo and remove (set to NaN)
        ibad = np.where(((data0["Z_H"])["values"] < 10.0) & (zzz <= 4.0))
        nbad = len(ibad[0])
        if nbad > 0:
            ((data0["Z_H"])["values"])[ibad] = float("nan")

        # Replace NaNs that were removed
        if nnan > 0:
            ((data0["Z_H"])["values"])[inan] = float("nan")

        # Second check for weak, low-level echo
        inan = np.where(np.isnan((data0["Z_H"])["values"]))  # Find bins with NaNs
        nnan = len(inan[0])  # Count number of bins with NaNs

        if nnan > 0:
            ((data0["Z_H"])["values"])[inan] = 0.0

        refl_max = np.nanmax((data0["Z_H"])["values"], axis=0)
        echo0_max = np.nanmax(((data0["Z_H"])["values"] > 0.0) * zzz, axis=0)
        echo0_min = np.nanmin(((data0["Z_H"])["values"] > 0.0) * zzz, axis=0)
        echo5_max = np.nanmax(((data0["Z_H"])["values"] > 5.0) * zzz, axis=0)
        echo15_max = np.nanmax(((data0["Z_H"])["values"] > 15.0) * zzz, axis=0)

        # Replace NaNs that were removed
        if nnan > 0:
            ((data0["Z_H"])["values"])[inan] = float("nan")

        # Find weak and/or shallow echo
        ibad = np.where(
            ((refl_max < 20.0) & (echo0_max <= 4.0) & (echo0_min <= 3.0))
            | ((refl_max < 10.0) & (echo0_max <= 5.0) & (echo0_min <= 3.0))
            | ((echo5_max <= 5.0) & (echo5_max > 0.0) & (echo15_max <= 3.0))
            | ((echo15_max < 2.0) & (echo15_max > 0.0))
        )
        nbad = len(ibad[0])
        if nbad > 0:
            kbad = (np.zeros((nbad))).astype(int)
            for k in range(0, nz):
                ((data0["Z_H"])["values"])[(k + kbad), ibad[0], ibad[1]] = float("nan")

    # Find clutter below convective anvils
    k4km = ((np.where((data0["z"])["values"] >= 4.0))[0])[0]
    fin = np.isfinite((data0["Z_H"])["values"])
    ibad = np.where(
        (fin[k4km, :, :] == 0)
        & (np.sum(fin[k4km : nz - 1, :, :], axis=0) > 0)
        & (np.sum(fin[0 : k4km - 1, :, :], axis=0) > 0)
    )
    nbad = len(ibad[0])
    if nbad > 0:
        kbad = (np.zeros((nbad))).astype(int)
        for k in range(0, k4km + 1):
            ((data0["Z_H"])["values"])[(k + kbad), ibad[0], ibad[1]] = float("nan")

    # Second pass at removing speckles
    fin = np.isfinite((data0["Z_H"])["values"])

    # Compute fraction of neighboring points with echo
    cover = np.zeros((nz, ny, nx))
    for i in range(-2, 3):
        for j in range(-2, 3):
            cover += np.roll(np.roll(fin, i, axis=2), j, axis=1)
    cover = cover / 25.0

    # Find bins with low nearby areal echo coverage (i.e., speckles) and remove (set to NaN).
    ibad = np.where(cover <= areal_coverage_thresh)
    nbad = len(ibad[0])
    if nbad > 0:
        ((data0["Z_H"])["values"])[ibad] = float("nan")

    return data0


# GridRad sample image plotting routine
def plot_image(data):
    """Plot GridRad data from a dictionary created by the read_file() function.
    Save the file to disk with the name 'gridrad_image.png' in the current working
    directory.

    Parameters
    ----------
    data0 : dict
        Dictionary of GridRad data and attributes.

    Returns
    -------
    None
    """

    # Extract dimensions and their sizes
    x = (data["x"])["values"]
    y = (data["y"])["values"]
    nx = (data["x"])["n"]
    ny = (data["y"])["n"]

    r = [
        49,
        30,
        15,
        150,
        78,
        15,
        255,
        217,
        255,
        198,
        255,
        109,
        255,
        255,
        255,
    ]  # RGB color values
    g = [239, 141, 56, 220, 186, 97, 222, 164, 107, 59, 0, 0, 0, 171, 255]
    b = [237, 192, 151, 150, 25, 3, 0, 0, 0, 0, 0, 0, 255, 255, 255]

    refl_max = np.nanmax((data["Z_H"])["values"], axis=0)  # Column-maximum reflectivity

    img = np.zeros((ny, nx, 3))  # Create image for plotting
    img[:] = 200.0 / 255.0  # Set default color to gray

    ifin = np.where(np.isfinite(refl_max))  # Find finite values
    nfin = len(ifin[0])  # Count number of finite values

    for i in range(0, nfin):
        img[(ifin[0])[i], (ifin[1])[i], :] = (
            r[min(float(refl_max[(ifin[0])[i], (ifin[1])[i]] / 5), 14)] / 255.0,
            g[min(float(refl_max[(ifin[0])[i], (ifin[1])[i]] / 5), 14)] / 255.0,
            b[min(float(refl_max[(ifin[0])[i], (ifin[1])[i]] / 5), 14)] / 255.0,
        )

    imgplot = plt.imshow(img[::-1, :, :], extent=[x[0], x[nx - 1], y[0], y[ny - 1]])
    imgplot.savefig("gridrad_image.png")
