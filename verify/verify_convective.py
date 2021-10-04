import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr
from metpy.units import units
from sklearn.metrics import roc_auc_score

import probabilistic_verification


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Verify probabilistic neighborhood forecasts"
    )
    parser.add_argument(
        "experiment", type=str, help="The ensemble experiment to verify"
    )
    parser.add_argument(
        "fcst_key", type=str, help="Key in dataset for forecast probabilities"
    )
    parser.add_argument(
        "obs_key",
        type=str,
        help="Key in observation dataset or description of observation probabilities",
    )
    parser.add_argument(
        "radius_idx",
        type=int,
        help="Index in dataset of the neighborhood radius to verify",
    )
    parser.add_argument("dir_out", type=str, help="Directory to write files to")
    parser.add_argument(
        "--init_start",
        type=str,
        default="2016042700",
        help="First initialization date to verify",
    )
    parser.add_argument(
        "--init_end",
        type=str,
        default="2016060312",
        help="Last initialization date to verify",
    )
    parser.add_argument(
        "--init_freq",
        type=str,
        default="12H",
        help="Time interval between initializations as a `pandas` compatible frequency",
    )
    parser.add_argument(
        "--nhours",
        type=int,
        default=48,
        help="Total number of forecast hours to verify",
    )
    parser.add_argument(
        "--dt_hours", type=int, default=1, help="Forecast output interval in hours"
    )
    parser.add_argument(
        "--path_ref",
        type=str,
        default="/lustre/scratch/rmanser/wrfref/wrfoutREFd02",
        help="Reference file for WRF base fields and attributes",
    )

    path = Path("/lustre/scratch/rmanser")
    fmt = "%Y%m%d%H"

    args = parser.parse_args()
    exp = args.experiment
    fcst_key = args.fcst_key
    obs_key = args.obs_key
    radius_idx = args.radius_idx
    dir_out = Path(args.dir_out)
    init_start = pd.to_datetime(args.init_start, format=fmt)
    init_end = pd.to_datetime(args.init_end, format=fmt)
    init_freq = args.init_freq
    nhours = args.nhours
    dt_hours = args.dt_hours
    path_ref = Path(args.path_ref)

    inits = pd.date_range(init_start, init_end, freq=init_freq)
    fhours = np.arange(dt_hours, nhours + dt_hours, dt_hours)

    # The recenter ensemble has no forecasts for these inits
    # This could be added as an optional argument with multiple values in the future...
    bad_inits = [
        pd.Timestamp("2016-04-30 12:00"),
        pd.Timestamp("2016-05-01 00:00"),
        pd.Timestamp("2016-05-01 12:00"),
    ]

    bins = (
        np.array([5.0, 15.0, 25.0, 35.0, 45.0, 55.0, 65.0, 75.0, 85.0, 95.0, 100.0])
        * units.percent
    )

    fss = np.full((len(inits), nhours), np.nan)
    bss = np.full((len(inits), nhours), np.nan)
    freq = np.full((len(inits), nhours, len(bins)), np.nan)
    hits = np.full((len(inits), nhours, len(bins)), np.nan)
    bin_mean = np.full((len(inits), nhours, len(bins)), np.nan)
    auc = np.full((len(inits), nhours), np.nan)

    # ----------------------
    # Open observation files
    # ----------------------

    dates = pd.date_range("2016-04-27 00:00", "2016-06-05 12:00", freq="1H")
    dates_da = xr.DataArray(data=dates, name="date", dims="date")
    if "col_max_refl" in obs_key:
        files = [
            path / "gr_neps" / f'gridrad_{d.strftime("%Y%m%d%H")}.nc' for d in dates
        ]
        obs = xr.open_mfdataset(files, concat_dim=dates_da, combine="nested")
        obs_subset = obs[obs_key].sel(radii=radius_idx).load().values * units.percent
    elif "precip" in obs_key:
        files = [
            path / "st4_nps" / f'stage4_{d.strftime("%Y%m%d%H")}.nc' for d in dates
        ]
        obs = xr.open_mfdataset(files, concat_dim=dates_da, combine="nested")
        obs_subset = obs[obs_key].sel(radii=radius_idx).load().values * units.percent
    elif "practically_perfect" in obs_key:
        files = [
            path / "practically_perfect" / f'ppp_{d.strftime("%Y%m%d%H")}.nc'
            for d in dates
        ]
        obs = xr.open_mfdataset(files, concat_dim=dates_da, combine="nested")
        obs_subset = (
            obs[obs_key].isel(radii=radius_idx).load().values * units.dimensionless
        ).to("percent")
    else:
        raise ValueError(f"Observation key {obs_key} not supported")

    # ----------------------------------------------------------------------------------------
    # Sample climatology and uncertainty for BSS and attributes statistics (Wilks 2011, book)
    # ----------------------------------------------------------------------------------------
    locs = np.where(obs_subset > 0.0 * units.percent)
    obs_bin = np.zeros_like(obs_subset)
    obs_subset[locs] = 100.0 * units.percent

    sample_climo = probabilistic_verification.sample_climatology_of_probabilities(
        obs_subset
    )
    uncertainty = probabilistic_verification.uncertainty_of_probabilities(sample_climo)

    # ----------------
    # Verify forecasts
    # ----------------

    for i, init in enumerate(inits):
        if exp == "recenter" and init in bad_inits:
            continue

        files = sorted(
            path.glob(f'wrf_post/{exp}/{init.strftime("%Y%m%d%H")}/convective_f*.nc')
        )
        if len(files) < 48:
            print(
                f"Only found {len(files)} of 48 files. Skipping initialization {init}"
            )
            continue

        fcst = xr.open_mfdataset(files, concat_dim="forecast_hour", combine="nested")

        for h, hour in enumerate(fhours):

            fprobs = fcst[fcst_key].values[h, radius_idx] * units(fcst[fcst_key].units)
            date = init + pd.Timedelta(f"{hour} hours")

            oprobs = obs[obs_key].isel(radii=radius_idx).sel(date=date).values
            if obs_key == "practically_perfect_probabilities":
                oprobs = (oprobs * units.dimensionless).to("percent")
            else:
                oprobs = oprobs * units.percent

            # FSS requires fractional probabilities
            fss[i, h] = probabilistic_verification.fss(fprobs, oprobs)

            # All other verification measures require binary probabilities
            locs = np.where(oprobs > 0.0 * units.percent)
            oprobs[locs] = 100.0 * units.percent

            bss[i, h] = probabilistic_verification.brier_score(
                fprobs, oprobs, skill_score=True, ref=uncertainty
            )

            (
                freq[i, h],
                hits[i, h],
                bin_mean[i, h],
            ) = probabilistic_verification.reliability(fprobs, oprobs, bins)

            try:
                auc[i, h] = roc_auc_score(oprobs.flatten(), fprobs.flatten())
            except ValueError:
                print("*** Warning: undefined ROC AUC. Setting value to np.nan\n")
                auc[i, h] = np.nan

    sample_climo = xr.DataArray(
        data=sample_climo.m, attrs={"units": str(sample_climo.units)}
    )
    uncertainty = xr.DataArray(
        data=uncertainty.m, attrs={"units": str(uncertainty.units)}
    )

    dims = ["initialization", "forecast_hour"]
    dims_reliability = ["initialization", "forecast_hour", "bins"]
    coords = {
        "initialization": inits,
        "forecast_hour": fhours,
        "bins": bins,
    }
    data_vars = {
        "fss": (dims, fss),
        "bss": (dims, bss),
        "frequency": (dims_reliability, freq),
        "hits": (dims_reliability, hits),
        "bin_mean": (dims_reliability, bin_mean),
        "roc_area": (dims, auc),
        "climatology": sample_climo,
        "uncertainty": uncertainty,
    }
    ds = xr.Dataset(data_vars, coords)
    path_save = dir_out / exp
    path_save.mkdir(exist_ok=True, parents=True)
    ds.to_netcdf(path_save / f"{fcst_key}_r{radius_idx}.nc")
