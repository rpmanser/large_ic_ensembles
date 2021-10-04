# probabilistic_verification.py

"""Verification metrics and calculations for gridded probabilistic forecasts."""

import numpy as np
from metpy.units import units


def fss(fcst, obs, return_fbs=False):
    """Calculate fractions skill score (FSS) for a gridded probabilstic forecast.

    Parameters
    ----------
    fcst : N x M pint.Quantity
        Forecast probabilities to verify.
    obs : N x M pint.Quantity
        Observation probabilities to verify forecast against.
    return_fbs : bool
        Return fractions Brier Score and reference fractions Brier score in addition to FSS.

    Returns
    -------
    float or 3-tuple of float
    """
    nxny = fcst.size
    fcst = fcst.to("dimensionless").m
    obs = obs.to("dimensionless").m

    if np.max(fcst) > 0.0 or np.max(obs) > 0.0:
        fbs = ((fcst - obs) ** 2).sum() / nxny
        fbs_worst = (fcst ** 2 + obs ** 2).sum() / nxny
        fss = 1 - fbs / fbs_worst

    elif return_fbs:
        return np.nan, np.nan, np.nan
    else:
        return np.nan

    if return_fbs:
        return fss, fbs, fbs_worst
    else:
        return fss


def brier_score(fcst, obs, skill_score=False, ref=None):
    """Calculate the Brier score (BS) for a gridded probabilistic forecast.

    Parameters
    ----------
    fcst : N x M pint.Quantity
        Forecast probabilities to verify.
    obs : N x M pint.Quantity
        Observation probabilities to verify forecast against.
    skill_score : bool (optional)
        Return the Brier Skill Score (BSS) instead of BS, where the reference
        forecast is the mean of `obs`, unless `ref` is given. Default is False.
    ref : scalar pint.Quantity (optional)
        Reference forecast value for computing the skill score. If `ref` is
        given, `skill_score` is assumed to be `True` unless specified `False`.

    Returns
    -------
    float
    """
    n = fcst.size
    f = fcst.to("dimensionless").m
    o = obs.to("dimensionless").m

    bs = (1 / n) * np.nansum((f - o) ** 2)

    if skill_score and ref is not None:
        return 1 - (bs / ref.to("dimensionless"))
    elif skill_score:
        ref = (1 / n) * np.nansum((np.nanmean(o) - o) ** 2)
        return 1 - (bs / ref)
    return bs


def sample_climatology_of_probabilities(obs_prob):
    """Calculate the sample climatology of gridded probabilistic observations.

    Parameters
    ----------
    obs_prob : scalar pint.Quantity
        Observed probabilities.

    Returns
    -------
    pint.Quantity
        Sample climatology as a *dimensionless* value, regardless of units on `obs`.
    """
    obs_dimless = obs_prob.to("dimensionless")
    return np.mean(obs_dimless)


def uncertainty_of_probabilities(climo):
    """Calculate the uncertainty of a climatology of gridded probabilistic observations.

    Parameters
    ----------
    climo : scalar pint.Quantity
        Climatological value for an observed probability.

    Returns
    -------
    pint.Quantity
        Uncertainty as a *dimensionless* value, regardless of units on `climo`.
    """
    climo_dimless = climo.to("dimensionless")
    return climo_dimless * (1.0 * units.dimensionless - climo_dimless)


def reliability(probs_fcst, probs_obs, bins):
    """Calculate probabilistic forecast frequency and hits on a common grid between forecast
    and observations.

    Parameters
    ----------
    probs_fcst : numpy.ndarray
        Forecast probability values
    probs_obs : numpy.ndarray
        Observation probability values
    bins : array-like
        Probability bins against which to accumulate forecast frequencies and hits,
        excluding 0.

    Returns
    -------
    freq : numpy.ndarray
        Frequency of probability forecasts for each bin.
    hits : numpy.ndarray
        Hits of probability forecasts for each bin.
    bin_mean : numpy.ndarray
        Means of the forecast probabilities for each bin.
    """
    freq = np.zeros_like(bins)
    hits = np.zeros_like(bins)
    bin_mean = np.full_like(bins, fill_value=np.nan)

    lower = 0.0
    for i, p_i in enumerate(bins):
        if lower == 0.0:
            thresh_field = (lower <= probs_fcst) & (probs_fcst <= p_i)
        else:
            thresh_field = (lower < probs_fcst) & (probs_fcst <= p_i)

        freq[i] = len(np.asarray(thresh_field).nonzero()[0])
        hits[i] = len(np.asarray(thresh_field & (probs_obs > lower)).nonzero()[0])
        bin_mean[i] = np.nanmean(probs_fcst[thresh_field])

        lower = p_i

    return freq, hits, bin_mean
