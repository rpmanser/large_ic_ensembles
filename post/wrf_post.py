# =============================================================================
# test_wrf_post.py
# -----------------------------------------------------------------------------
# Test if this script is feasible for WRF post-processing. Pay attention to memory
# use from tracemalloc, especially peak memory use.
#
# From running through 3 ensemble members for a single forecast hour, peak usage
# hits about 2.78 GB after opening member 2. Each consecutive member adds, at
# worst, about 0.1 GB to the peak, meaning opening 42 members costs up to 6.88 GB.
# =============================================================================

import argparse
import logging
import sys
import tracemalloc
from pathlib import Path

import metpy.calc as mpcalc
import metpy.interpolate as mpinterp
import numpy as np
import pandas as pd
import probcalc_numpy
import wrf
import wrf_ens_tools.post as wrfpost
import xarray as xr
from metpy.units import units


def print_memory_use():
    current, peak = tracemalloc.get_traced_memory()
    # Convert Gibibytes to Gigabytes
    print(f"Current memory use = {(current / 1024 ** 3) * 1.073742} GB")
    print(f"Peak memory use = {(peak / 1024 ** 3) * 1.073742} GB\n")


def main():

    description = (
        "Post process WRF CAM ensemble forecasts. This script assumes that WRF files"
        "are located in a directory `directory` that contains subdirectories for each"
        "ensemble member labeled as mem{n}, where n is an integer. Within those directories,"
        "it is assumed that WRF forecast files have the naming convention "
        "wrfout_d0{domain}_YYYY-MM-DD_HH:00:00 unless otherwise specified by the optional"
        "arguments `--prefix`, `--date_fmt`, and `--suffix`."
    )
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "directory", type=str, help="Parent directory of WRF forecast files"
    )
    parser.add_argument(
        "initialization", type=str, help="Initialization date (YYYYMMDDHH)"
    )
    parser.add_argument("fhour", type=int, help="Forecast hour to process")
    parser.add_argument("nmem", type=int, help="Number of ensemble members")
    parser.add_argument("domain", type=int, help="WRF domain number")
    parser.add_argument(
        "--skip_convective", action="store_true", help="Skip convective post-processing"
    )
    parser.add_argument(
        "--path_ref",
        type=str,
        default=None,
        help=(
            "Path to a WRF reference file containing coordinates, base state variables, "
            "and model configuration options. If None, it is assumed that all coordinates, "
            "base state variables, and model configuration options can be found in each file."
        ),
    )
    parser.add_argument(
        "--path_save",
        type=str,
        default=".",
        help=(
            "Directory in which to save output files. An attempt will be made to create the "
            "directory if it doesn't exist."
        ),
    )
    parser.add_argument(
        "--prefix",
        type=str,
        default="wrfout_d02_",
        help="Characters preceeding the date in each WRF file name",
    )
    parser.add_argument(
        "--date_fmt",
        type=str,
        default="%Y-%m-%d_%H:%M:%S",
        help="Date format in each WRF file name",
    )
    parser.add_argument(
        "--suffix",
        type=str,
        default="",
        help="Characters following the date in each WRF file name",
    )
    parser.add_argument(
        "--profile",
        action="store_true",
        help=(
            "Profile this script for memory and time performance (this may significantly"
            "reduce overall performance of the script)"
        ),
    )

    args = parser.parse_args()
    directory = Path(args.directory)
    init = pd.to_datetime(args.initialization, format="%Y%m%d%H")
    fhour = args.fhour
    nmem = args.nmem
    domain = args.domain
    skip_convective = args.skip_convective
    path_ref = Path(args.path_ref)
    path_save = Path(args.path_save)
    prefix = args.prefix
    date_fmt = args.date_fmt
    suffix = args.suffix
    profile = args.profile

    log = logging.getLogger(sys.argv[0])
    log.addHandler(logging.NullHandler())
    # logging.basicConfig(level=os.environ["LOG_LEVEL"])
    logging.basicConfig(level="DEBUG")

    # log.debug('Argument "directory":', directory)
    # log.debug('Argument "init":', init)
    # log.debug('Argument "fhour":', fhour)
    # log.debug('Argument "nmem":', nmem)
    # log.debug('Argument "path_ref":', path_ref)
    # log.debug('Argument "path_save":', path_save)
    # log.debug('Argument "prefix":', prefix)
    # log.debug('Argument "date_fmt":', date_fmt)
    # log.debug('Argument "suffix":', suffix)
    # log.debug('Argument "profile":', profile)

    print('Argument "directory":', directory)
    print('Argument "init":', init)
    print('Argument "fhour":', fhour)
    print('Argument "nmem":', nmem)
    print('Argument "domain":', domain)
    print('Argument "skip_convective":', skip_convective)
    print('Argument "path_ref":', path_ref)
    print('Argument "path_save":', path_save)
    print('Argument "prefix":', prefix)
    print('Argument "date_fmt":', date_fmt)
    print('Argument "suffix":', suffix)
    print('Argument "profile":', profile)

    if profile:
        tracemalloc.start()
        time_start = pd.Timestamp.now()

    if path_ref is not None:
        ref = xr.open_dataset(path_ref).sel(Time=0)

    path_save.mkdir(exist_ok=True, parents=True)

    levels = np.array([850.0, 700.0, 500.0, 300.0]) * units("hectopascal")
    radii = np.array([32.0, 64.0, 96.0]) * units("kilometer")
    thresholds = {
        "precipitation": np.array([0.254, 2.54, 6.35, 12.7, 25.4])
        * units("millimeter"),
        "reflectivity": np.array([25.0, 40.0]),
        "updraft_helicity": np.array([25.0, 40.0, 100.0])
        * units("meter ** 2 / second ** 2"),
    }

    lead = init + pd.Timedelta(fhour, unit="hour")

    upper_names = [
        "temperature",
        "u_wind_component",
        "v_wind_component",
        "wind_speed",
        "geopotential_height",
        "dewpoint_temperature",
    ]

    surface_names = [
        "temperature_2_meter",
        "u_wind_component_10_meter",
        "v_wind_component_10_meter",
        "wind_speed_10_meter",
        "mean_sea_level_pressure",
        "dewpoint_temperature_2_meter",
    ]

    # Convective -- every hour
    members_precip = {}
    members_uh = {}
    members_refl = {}

    # Surface -- every 6 hours
    members_u10 = {}
    members_v10 = {}
    members_wspd10 = {}
    members_t2 = {}
    members_dpt2 = {}
    members_mslp = {}

    # Upper -- every 12 hours
    members_temperature = {}
    members_u = {}
    members_v = {}
    members_wspd = {}
    members_z = {}
    members_dpt = {}

    attrs_all = {
        "initialization": init.strftime("%Y-%m-%d %H:%M:%S"),
        "forecast_hour": fhour,
        "domain": domain,
    }

    for mem in range(1, nmem + 1):

        log.info(f"Opening WRF member file {mem}")
        possible_names = [
            f"mem{mem}/wrfoutred/wrfout_d02_red_{lead.strftime(date_fmt)}.gz",
            f"mem{mem}/wrfoutred/wrfout_d02_red_{lead.strftime(date_fmt)}",
            f"mem{mem}/wrfout_d02_red_{lead.strftime(date_fmt)}.gz",
            f"mem{mem}/wrf/wrfout_d02_{lead.strftime(date_fmt)}",
            f"mem{mem}/wrfout_d02_{lead.strftime(date_fmt)}.gz",
            f"mem{mem}/wrfout_d02_{lead.strftime(date_fmt)}",
            f"mem{mem}/wrfout_d02_red_{lead.strftime(date_fmt)}.gz",
            f"mem{mem}/wrfout_d02_red_{lead.strftime(date_fmt)}",
        ]
        file = ""
        for name in possible_names:
            if (directory / name).exists():
                file = name
                break

        try:
            ds = xr.open_dataset(directory / file).sel(Time=0)
        except (FileNotFoundError, OSError):
            log.error(f"None of the following files were found in {directory}:")
            for name in possible_names:
                log.error(name)
            exit(1)

        if path_ref is None:
            logging.debug(
                "No argument given for WRF reference file. "
                "Looking for base state variables in input dataset"
            )
            ref = ds

        # Handle hourly convective variables
        # ---------------------------------------------------------------------
        if fhour >= 1 and not skip_convective:
            precip = (ds.RAINNC + ds.RAINC).values * units(ds.RAINNC.units)
            # Subtract accumulated precip from the previous forecast hour to get hourly precip
            if fhour == 1:
                precip_prev = np.zeros_like(precip) * precip.units
            else:
                for name in possible_names:
                    name = name.replace(
                        lead.strftime(date_fmt),
                        (lead - pd.Timedelta(1, unit="hour")).strftime(date_fmt),
                    )
                    if (directory / name).exists():
                        file_prev = name
                        break
                try:
                    ds_prev = xr.open_dataset(directory / file_prev).sel(Time=0)
                    precip_prev = (ds_prev.RAINC + ds_prev.RAINNC).values * units(
                        ds_prev.RAINNC.units
                    )
                except (FileNotFoundError, OSError):
                    log.error(f"Could not open file {directory / file_prev}")
                    exit(1)

            members_precip[f"mem{mem}"] = precip - precip_prev
            members_uh[f"mem{mem}"] = ds.UP_HELI_MAX.values * units(
                ds.UP_HELI_MAX.units
            )
            members_refl[f"mem{mem}"] = np.max(ds.REFL_10CM.values, axis=0)

        # Handle 6-hourly surface variables
        # ---------------------------------------------------------------------
        if fhour % 6 == 0:
            log.info(f"Working on surface variables for hour {fhour}")
            t2 = ds.T2.values * units(ds.T2.units)
            psfc = ds.PSFC.values * units(ds.PSFC.units)
            qv2 = ds.Q2.values * units(ds.Q2.units)
            u10 = ds.U10.values
            v10 = ds.V10.values

            spec_h2 = mpcalc.specific_humidity_from_mixing_ratio(qv2)
            u10earth, v10earth = wrfpost.earth_relative_winds(
                u10, v10, ref.SINALPHA, ref.COSALPHA
            )
            u10earth = u10earth.values * units(ds.U10.units)
            v10earth = v10earth.values * units(ds.V10.units)

            # Sea level pressure requires 3-D model variables to calculate
            p = (ref.PB + ds.P).values * units(ds.P.units)
            gpot = wrfpost.destagger(ref.PHB.values + ds.PH.values, 0) * units(
                ds.PH.units
            )
            theta = (ds.T + ref.T00).values * units(ds.T.units)
            qv = ds.QVAPOR.values * units(ds.QVAPOR.units)

            z = mpcalc.geopotential_to_height(gpot)
            t = mpcalc.temperature_from_potential_temperature(p, theta)

            try:
                mslp = wrf.slp(
                    z.to("meter").m,
                    t.to("kelvin").m,
                    p.to("pascal").m,
                    qv.m,
                    units="hPa",
                ).values * units("hPa")
            except wrf.DiagnosticError:
                log.error(
                    f"Error when calculating SLP for member {mem} and hour {fhour}"
                )
                log.error("Setting SLP to NaN")
                mslp = np.full_like(t2, np.nan)

            members_t2[f"mem{mem}"] = t2
            members_u10[f"mem{mem}"] = u10earth
            members_v10[f"mem{mem}"] = v10earth
            members_mslp[f"mem{mem}"] = mslp
            members_dpt2[f"mem{mem}"] = mpcalc.dewpoint_from_specific_humidity(
                psfc, t2, spec_h2
            )
            members_wspd10[f"mem{mem}"] = mpcalc.wind_speed(u10earth, v10earth)

        # Handle 12-hourly upper air variables
        # ---------------------------------------------------------------------
        if fhour % 12 == 0:
            log.info(f"Working on upper air variables for hour {fhour}")
            u = wrfpost.destagger(ds.U.values, 2) * units(ds.U.units)
            v = wrfpost.destagger(ds.V.values, 1) * units(ds.V.units)
            gpot = wrfpost.destagger(ref.PHB.values + ds.PH.values, 0) * units(
                ds.PH.units
            )
            p = (ref.PB + ds.P).values * units(ds.P.units)
            theta = (ds.T + ref.T00).values * units(ds.T.units)
            qv = ds.QVAPOR.values * units(ds.QVAPOR.units)

            sinalpha = np.broadcast_to(ref.SINALPHA, u.shape)
            cosalpha = np.broadcast_to(ref.COSALPHA, u.shape)
            uearth, vearth = wrfpost.earth_relative_winds(u, v, sinalpha, cosalpha)
            t = mpcalc.temperature_from_potential_temperature(p, theta)
            spec_h = mpcalc.specific_humidity_from_mixing_ratio(qv)
            dpt = mpcalc.dewpoint_from_specific_humidity(p, t, spec_h)
            wspd = mpcalc.wind_speed(uearth, vearth)
            z = mpcalc.geopotential_to_height(gpot)

            t850 = (mpinterp.interpolate_to_isosurface(p, t, levels[0])).to("kelvin")
            t700 = (mpinterp.interpolate_to_isosurface(p, t, levels[1])).to("kelvin")
            t500 = (mpinterp.interpolate_to_isosurface(p, t, levels[2])).to("kelvin")
            t300 = (mpinterp.interpolate_to_isosurface(p, t, levels[3])).to("kelvin")

            u850 = (mpinterp.interpolate_to_isosurface(p, uearth, levels[0])).to("m/s")
            u700 = (mpinterp.interpolate_to_isosurface(p, uearth, levels[1])).to("m/s")
            u500 = (mpinterp.interpolate_to_isosurface(p, uearth, levels[2])).to("m/s")
            u300 = (mpinterp.interpolate_to_isosurface(p, uearth, levels[3])).to("m/s")

            v850 = (mpinterp.interpolate_to_isosurface(p, vearth, levels[0])).to("m/s")
            v700 = (mpinterp.interpolate_to_isosurface(p, vearth, levels[1])).to("m/s")
            v500 = (mpinterp.interpolate_to_isosurface(p, vearth, levels[2])).to("m/s")
            v300 = (mpinterp.interpolate_to_isosurface(p, vearth, levels[3])).to("m/s")

            wspd850 = (mpinterp.interpolate_to_isosurface(p, wspd, levels[0])).to("m/s")
            wspd700 = (mpinterp.interpolate_to_isosurface(p, wspd, levels[1])).to("m/s")
            wspd500 = (mpinterp.interpolate_to_isosurface(p, wspd, levels[2])).to("m/s")
            wspd300 = (mpinterp.interpolate_to_isosurface(p, wspd, levels[3])).to("m/s")

            z850 = (mpinterp.interpolate_to_isosurface(p, z, levels[0])).to("meter")
            z700 = (mpinterp.interpolate_to_isosurface(p, z, levels[1])).to("meter")
            z500 = (mpinterp.interpolate_to_isosurface(p, z, levels[2])).to("meter")
            z300 = (mpinterp.interpolate_to_isosurface(p, z, levels[3])).to("meter")

            dpt850 = (mpinterp.interpolate_to_isosurface(p, dpt, levels[0])).to(
                "kelvin"
            )
            dpt700 = (mpinterp.interpolate_to_isosurface(p, dpt, levels[1])).to(
                "kelvin"
            )
            dpt500 = (mpinterp.interpolate_to_isosurface(p, dpt, levels[2])).to(
                "kelvin"
            )
            dpt300 = (mpinterp.interpolate_to_isosurface(p, dpt, levels[3])).to(
                "kelvin"
            )

            members_temperature[f"mem{mem}"] = np.stack(
                [t850, t700, t500, t300], axis=0
            )
            members_u[f"mem{mem}"] = np.stack([u850, u700, u500, u300], axis=0)
            members_v[f"mem{mem}"] = np.stack([v850, v700, v500, v300], axis=0)
            members_wspd[f"mem{mem}"] = np.stack(
                [wspd850, wspd700, wspd500, wspd300], axis=0
            )
            members_z[f"mem{mem}"] = np.stack([z850, z700, z500, z300], axis=0)
            members_dpt[f"mem{mem}"] = np.stack(
                [dpt850, dpt700, dpt500, dpt300], axis=0
            )

    # Save surface variables to file
    # -------------------------------------------------------------------------
    if fhour % 6 == 0:
        t2 = np.stack([v for v in members_t2.values()])
        u10 = np.stack([v for v in members_u10.values()])
        v10 = np.stack([v for v in members_v10.values()])
        dpt2 = np.stack([v for v in members_dpt2.values()])
        wspd10 = np.stack([v for v in members_wspd10.values()])
        mslp = np.stack([v for v in members_mslp.values()])

        dims = ["member", "y", "x"]
        coords = {
            "member": np.arange(1, nmem + 1),
            "y": ref.south_north.values,
            "x": ref.west_east.values,
        }

        data_vars = {}
        for name, vr in zip(surface_names, (t2, u10, v10, wspd10, mslp, dpt2)):
            data_vars[name] = (
                dims,
                vr.m,
                {"description": f'{name.replace("_", " ")}', "units": str(vr.units)},
            )

        attrs = {
            "description": "WRF ensemble model output near the surface",
        }
        attrs.update(attrs_all)

        ds_surface = xr.Dataset(data_vars, coords, attrs)
        ds_surface.to_netcdf(path_save / f"surface_f{str(fhour).zfill(2)}.nc")

    # Save upper air variables to file
    # -------------------------------------------------------------------------
    if fhour % 12 == 0:
        t = np.stack([v for v in members_temperature.values()])
        u = np.stack([v for v in members_u.values()])
        v = np.stack([v for v in members_v.values()])
        wspd = np.stack([v for v in members_wspd.values()])
        z = np.stack([v for v in members_z.values()])
        dpt = np.stack([v for v in members_dpt.values()])

        dims = ["member", "pressure", "y", "x"]
        coords = {
            "member": np.arange(1, nmem + 1),
            "pressure": levels.m,
            "y": ref.south_north.values,
            "x": ref.west_east.values,
        }

        data_vars = {}
        for name, vr in zip(upper_names, (t, u, v, wspd, z, dpt)):
            data_vars[name] = (
                dims,
                vr.m,
                {
                    "description": (
                        f'{name.replace("_", " ")} interpolated to pressuresurfaces'
                    ),
                    "units": str(vr.units),
                },
            )

        attrs = {
            "description": (
                "WRF ensemble model output linearly interpolated to pressure surfaces"
            ),
        }
        attrs.update(attrs_all)

        ds_upper = xr.Dataset(data_vars, coords, attrs)
        ds_upper.to_netcdf(path_save / f"upper_f{str(fhour).zfill(2)}.nc")

    # Calculate probabilities for convective variables and save member and
    # probabilistic forecasts to file for non-zero forecast hours
    # -------------------------------------------------------------------------
    if fhour > 0 and not skip_convective:
        precip = np.stack([v for v in members_precip.values()])
        uh = np.stack([v for v in members_uh.values()])
        refl = np.stack([v for v in members_refl.values()])

        dims = ["radius", "y", "x"]
        coords = {
            "radius": (["radius"], radii.m, {"units": str(radii.units)}),
            "member": np.arange(1, nmem + 1),
            "y": ref.south_north.values,
            "x": ref.west_east.values,
        }
        data_vars = {}

        for thresh in thresholds["precipitation"]:
            probs = {}
            for radius in radii:
                thresh = thresh.to(precip.units)
                probs[f"{radius.m}"] = probcalc_numpy.nmep(precip.m, radius.m, thresh.m)

            description = (
                f"NMEPs for 1-hour accumulated precipitation >= {thresh} {thresh.units}"
            )
            data_vars[f'nmep_precipitation_{str(thresh.m).replace(".", "_")}'] = (
                dims,
                np.stack([v for v in probs.values()]),
                {"description": description, "units": str(probs.values[0].units)},
            )

        for thresh in thresholds["reflectivity"]:
            probs = {}
            for radius in radii:
                probs[f"{radius.m}"] = probcalc_numpy.nmep(refl, radius.m, thresh)

            description = f"NMEPs for column maximum reflectivity >= {thresh} dBZ"
            data_vars[f'nmep_reflectivity_{str(thresh).replace(".", "_")}'] = (
                dims,
                np.stack([v for v in probs.values()]),
                {"description": description, "units": str(probs.values[0].units)},
            )

        for thresh in thresholds["updraft_helicity"]:
            probs = {}
            for radius in radii:
                thresh = thresh.to(uh.units)
                probs[f"{radius.m}"] = probcalc_numpy.nmep(uh.m, radius.m, thresh.m)

            description = (
                f"NMEPs for hourly maximum updraft helicity >= {thresh} {thresh.units}"
            )
            data_vars[f'nmep_updraft_helicity_{str(thresh.m).replace(".", "_")}'] = (
                dims,
                np.stack([v for v in probs.values()]),
                {"description": description, "units": str(probs.values[0].units)},
            )

        dims = ["member", "y", "x"]
        data_vars["precipitation"] = (
            dims,
            precip.m,
            {
                "description": "1-hour accumulated precipitation",
                "units": str(precip.units),
            },
        )
        data_vars["reflectivity"] = (
            dims,
            refl,
            {"description": "Column maximum reflectivity", "units": "dBZ"},
        )
        data_vars["updraft_helicity"] = (
            dims,
            uh.m,
            {"description": "Hourly maximum updraft helicity", "units": str(uh.units)},
        )

        attrs = {
            "description": (
                "Raw WRF ensemble member convective forecasts and neighborhood maximum"
                " ensemble probability forecasts."
            )
        }
        attrs.update(attrs_all)

        ds_convective = xr.Dataset(data_vars, coords, attrs)
        ds_convective.to_netcdf(path_save / f"convective_f{str(fhour).zfill(2)}.nc")

    if profile:
        print("Summary of performance:")
        print(f"Total run time: {pd.Timestamp.now() - time_start}")
        print_memory_use()


if __name__ == "__main__":
    main()
