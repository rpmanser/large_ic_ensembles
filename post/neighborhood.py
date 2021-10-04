# =============================================================================
# neighborhood.py
# -----------------------------------------------------------------------------
# Set of functions to perform neighborhood analyses on gridded fields. Follows
# methodology in Schwartz et al. (2017).
# -----------------------------------------------------------------------------
# R. P. Manser
# 3/29/2020
# =============================================================================

import numpy as np
from scipy.spatial import cKDTree
from wrf_ens_tools.calc import coordinateSystems

import gridrad


def build_query(points, xi, search_radius):
    """Build a ball point query of a gridded 2D field using a KDTree

    Parameters
    ----------
    points : ndarray
        N x 2 data point locations
    xi : ndarray
        M x 2 analysis locations
    search_radius : float
        Length of neighborhood radius

    Returns
    -------
    query : ndarray of lists
        Array of lists of points within each queried neighborhood
    """
    tree = cKDTree(points)
    query = tree.query_ball_point(xi, search_radius)
    return query


def max_bin_prob(xi, values, query):
    """Calculate the maximum binary probability of event occurrence within the neighborhoods
    defined by query.

    This function was designed to specfically work with a ball point query generated
    by scipy.spatial.cKDTree, but may work with other queries.

    Parameters
    ----------
    xi : ndarray
        M x 2 analysis locations
    values : ndarray
        N x 2 binary data values
    query : ndarray of lists
        Array of lists of points defining neighborhoods over which to perform the analysis

    Returns
    -------
    analysis : ndarray
        Maximum binary probability field
    """
    analysis = np.zeros(xi.shape[0])

    for i, (analysis_point, neighbors) in enumerate(zip(xi, query)):
        data = values[neighbors]
        if np.any(data == 1.0):
            analysis[i] = 1.0
    return analysis


def nmep(xi, ens_field, query, axis=0):
    """Calculate the neighborhood maximum ensemble probability (NMEP) from a set
    of raw ensemble binary forecasts.

    This function was designed to specfically work with a ball point query generated
    by scipy.spatial.cKDTree, but may work with other queries.

    Parameters
    ----------
    xi : ndarray
        M x 2 analysis locations
    ens_field : ndarray
        P x N x M array of dichotomous ensemble forecasts, where P is ensemble
        members (unless axis is specified), N is the y-dimension, and M is the x-dimension
    query : ndarray of lists
        Array of lists of points defining neighborhoods over which to perform the analysis
    axis : int (default=0)
        Dimension along which ensemble member forecasts are aligned (default = 0)

    Returns
    -------
    nmep_analysis : ndarray
        N x M NMEP values
    """
    if axis != 0:
        ens_vals = np.moveaxis(ens_field, axis, 0)
    else:
        ens_vals = ens_field

    analyses = []
    for i in range(ens_vals.shape[0]):
        # values = ens_vals[i].flatten()
        # anl = max_bin_prob(xi, values, query)
        anl = max_bin_prob(xi, ens_vals[i].flatten(), query)
        anl.shape = ens_vals[i].shape
        analyses.append(anl)
    nmep_analysis = np.asarray(analyses)

    return nmep_analysis.mean(axis=0)


def neighbor_prob(xi, values, query):
    """Calculate the neighborhood probability of a 2-dimensional binary gridded field.

    Parameters
    ----------
    xi : ndarray
        M x 2 analysis locations
    values: ndarray
        N x 2 binary values
    query : ndarray of lists
        Array of lists of points defining neighborhoods over which to perform the analysis

    Returns
    -------
    np_analysis : ndarray
        M x 2 analysis values
    """
    analysis = np.zeros(xi.shape[0])

    for i, (analysis_point, neighbors) in enumerate(zip(xi, query)):
        data = values[neighbors]
        hits = np.nansum(data)
        npoints = len(neighbors)
        analysis[i] = hits / npoints

    return analysis


def open_rad_obs(path, level):
    """Open a GridRad observation file, filter and remove clutter from the reflectivity, then
    return reflectivity for the specified level.

    Paramters
    ---------
    path : str or os.path object
        Path to GridRad observation file
    level : int or str
        Vertical level in integer kilometers, or 'colmax' for column maximum, at which
        to return reflectivity values

    Returns
    -------
    N x M array
        Reflectivity over CONUS
    """
    raw = gridrad.read_file(path)
    filtered = gridrad.filter(raw)
    cleaned = gridrad.remove_clutter(filtered)
    if level == "colmax":
        refl = np.nanmax(cleaned["Z_H"]["values"], axis=0)
    else:
        refl = cleaned["Z_H"]["values"][level]
    return refl


def subset_to_forecast_grid(wrfref, obslon, obslat, obsalt=None, return_mask=False):
    """Subset gridded observations to a WRF grid.

    Subsetting is completed by converting both grids to earth-centered earth-fixed (ECEF)
    coordinates according to the WGS84 implementation standard and transforming observation
    coordinates to the native lambert conic conformal (LCC) WRF grid.

    Parameters
    ----------
    wrfref : xarray.Dataset object
        Reference file for the WRF grid with standard names for grid attributes, longitude
        values, and latitude values
    obslon : ndarray
        Gridded longitude values of observation locations
    obslat : ndarray
        Gridded latitude values of observation locations
    obsalt : ndarray, optional
        Gridded altitude values of observation locations. If None, all altitudes are assumed
        to be zero
    return_mask : bool, optional (default=False)
        Whether or not to return the mask used to subset the observations.

    Returns
    -------
    obs_x : ndarray
        Observation x locations transformed to LCC and subset to the WRF grid in Cartesian
        coordinates
    obs_y : ndarray
        Observation y locations transformed to LCC and subset to the WRF grid in Cartesian
        coordinates
    wrf_x : ndarray
        WRF grid x locations in Cartesian coordinates
    wrf_y
        WRF grid y locations in Cartesian coordinates
    grid_mask : ndarray
        Boolean 2D array used to subset observation domain to WRF grid
    """
    geo = coordinateSystems.GeographicSystem()
    lcc = coordinateSystems.MapProjection(
        projection="lcc",
        lon_0=wrfref.CEN_LON,
        lat_0=wrfref.CEN_LAT,
        lat_1=wrfref.TRUELAT1,
        lat_2=wrfref.TRUELAT2,
    )

    wrfalt = np.zeros_like(wrfref.XLONG[0])
    wrf_ecef = geo.toECEF(wrfref.XLONG.values[0], wrfref.XLAT.values[0], wrfalt)
    wrf_x, wrf_y, _ = lcc.fromECEF(*wrf_ecef)

    wrfmax_x = np.max(wrf_x)
    wrfmin_x = np.min(wrf_x)
    wrfmax_y = np.max(wrf_y)
    wrfmin_y = np.min(wrf_y)

    if obsalt is None:
        obsalt = np.zeros_like(obslon)
    obs_ecef = geo.toECEF(obslon, obslat, obsalt)
    obs_lcc_x, obs_lcc_y, _ = lcc.fromECEF(*obs_ecef)

    obs_x_mask = np.logical_and(obs_lcc_x < wrfmax_x, obs_lcc_x > wrfmin_x)
    obs_y_mask = np.logical_and(obs_lcc_y < wrfmax_y, obs_lcc_y > wrfmin_y)
    obs_mask = np.logical_and(obs_x_mask, obs_y_mask)

    obs_x = obs_lcc_x[obs_mask]
    obs_y = obs_lcc_y[obs_mask]

    if return_mask:
        return obs_x, obs_y, wrf_x, wrf_y, obs_mask
    else:
        return obs_x, obs_y, wrf_x, wrf_y
