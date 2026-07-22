"""Bootstrap power analysis for the sign-flip cluster permutation test.

Direct port of fn_bootstrap_power.m - see that file for the full method
description and caveats (case-resampling bootstrap: recombines the
between-subject variability already present in the original small sample,
so treat results as an optimistic ballpark for the sample size needed,
not a guarantee).

Parallelized across bootstrap replicates with joblib, which is the whole
point of moving this analysis to a cluster node with many cores instead
of running it serially in MATLAB on a laptop.
"""

import numpy as np
from joblib import Parallel, delayed

from fn_signflip_cluster_test2D import signflip_cluster_test_2d


def _one_bootstrap_2d(data, chance_level, n, tail, cfa, ca, n_perm_max, seed):
    rng = np.random.default_rng(seed)
    n_sub_orig = data.shape[0]
    idx = rng.integers(0, n_sub_orig, size=n)
    boot_data = data[idx]
    res = signflip_cluster_test_2d(
        boot_data,
        chance_level,
        tail=tail,
        cluster_forming_alpha=cfa,
        cluster_alpha=ca,
        n_perm_max=n_perm_max,
        rng=rng,
    )
    return any(c["sig"] for c in res["clusters"])


def _interp_n80(n_range, power, target=0.8):
    n_range = np.asarray(n_range, dtype=float)
    power = np.asarray(power, dtype=float)
    if np.all(power >= target):
        return float(n_range[0])
    if np.all(power < target):
        return float("nan")
    idx = int(np.argmax(power >= target))
    x1, x2 = n_range[idx - 1], n_range[idx]
    y1, y2 = power[idx - 1], power[idx]
    return x1 + (target - y1) * (x2 - x1) / (y2 - y1)


def bootstrap_power(
    data,
    chance_level,
    n_range,
    n_bootstrap,
    tail="right",
    cluster_forming_alpha=0.05,
    cluster_alpha=0.05,
    n_perm_max=100,
    n_jobs=-1,
    base_seed=0,
    verbose=True,
):
    """Estimate power vs. sample size via case-resampling bootstrap.

    Parameters
    ----------
    data : ndarray, shape (nSubOrig, T1, T2)
    chance_level : float
    n_range : sequence of int
        Hypothetical sample sizes to test.
    n_bootstrap : int
        Number of bootstrap resamples per sample size.
    n_jobs : int
        Passed to joblib.Parallel; -1 uses all available cores.

    Returns
    -------
    dict with keys: Nrange, power, nBootstrap, nSubOrig, chanceLevel,
    nPermMax, tail, N80
    """
    n_sub_orig = data.shape[0]
    power = np.zeros(len(n_range))

    for ni, n in enumerate(n_range):
        seeds = [base_seed + n * 1_000_003 + b for b in range(n_bootstrap)]
        results = Parallel(n_jobs=n_jobs)(
            delayed(_one_bootstrap_2d)(
                data, chance_level, n, tail, cluster_forming_alpha, cluster_alpha, n_perm_max, s
            )
            for s in seeds
        )
        power[ni] = float(np.mean(results))
        if verbose:
            print(f"    N={n}: power={power[ni]:.2f}", flush=True)

    return {
        "Nrange": np.asarray(n_range),
        "power": power,
        "nBootstrap": n_bootstrap,
        "nSubOrig": n_sub_orig,
        "chanceLevel": chance_level,
        "nPermMax": n_perm_max,
        "tail": tail,
        "N80": _interp_n80(n_range, power, 0.8),
    }
