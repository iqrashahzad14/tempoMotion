"""2D sign-flip cluster-based permutation test against a fixed chance level.

Direct Python port of fn_signflip_cluster_test2D.m - see that file for the
full method description (Maris & Oostenveld, 2007 style cluster-mass
permutation test, exact sign-flip enumeration for small N). Behavior is
matched as closely as possible:
  - one-sample t-statistic per pixel, deviation from a fixed chance level
  - cluster-forming threshold from a t critical value (one- or two-tailed)
  - 4-connectivity contiguous clusters (scipy.ndimage.label with a cross
    structuring element, matching the MATLAB flood-fill's 4-connectivity)
  - cluster mass = sum of |t| within the cluster
  - null distribution = max cluster mass across sign-flip permutations
    (exact enumeration of all 2^nSub combinations when feasible, else
    random Monte Carlo sampling)
  - cluster p-value = (# null max-mass >= observed mass + 1) / (nPerm + 1)
"""

from itertools import product

import numpy as np
from scipy import ndimage
from scipy.stats import t as t_dist

FOUR_CONNECTIVITY = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])


def _tstat(dev):
    """dev: (nSub, T1, T2) deviation from chance -> (T1, T2) t-statistic."""
    n = dev.shape[0]
    m = dev.mean(axis=0)
    s = dev.std(axis=0, ddof=0)
    s = np.where(s == 0, np.finfo(float).eps, s)
    return m / (s / np.sqrt(n))


def _find_clusters(tmap, tcrit, tail):
    if tail == "right":
        supra = tmap > tcrit
    elif tail == "left":
        supra = tmap < tcrit
    elif tail == "both":
        supra = np.abs(tmap) > tcrit
    else:
        raise ValueError("tail must be 'right', 'left', or 'both'")

    clusters = []
    if not supra.any():
        return clusters

    labeled, n_clusters = ndimage.label(supra, structure=FOUR_CONNECTIVITY)
    for c in range(1, n_clusters + 1):
        mask = labeled == c
        mass = float(np.abs(tmap[mask]).sum())
        clusters.append({"mask": mask, "mass": mass})
    return clusters


def signflip_cluster_test_2d(
    data,
    chance_level,
    tail="right",
    cluster_forming_alpha=0.05,
    cluster_alpha=0.05,
    n_perm_max=100000,
    rng=None,
):
    """2D sign-flip cluster-mass permutation test.

    Parameters
    ----------
    data : ndarray, shape (nSub, T1, T2)
        One page per subject, already averaged over decoding iterations.
    chance_level : float
        Scalar chance level to test against (e.g. 0.5, 0.25).
    tail : {'right', 'left', 'both'}
        'right' tests metric > chance (default).
    cluster_forming_alpha : float
        Per-pixel threshold for forming clusters.
    cluster_alpha : float
        Cluster-level significance threshold.
    n_perm_max : int
        If 2**nSub exceeds this, fall back to random sign-flip sampling
        instead of exact enumeration.
    rng : numpy.random.Generator, optional

    Returns
    -------
    dict with keys: nSub, chanceLevel, tail, clusterFormingAlpha,
    clusterAlpha, tobs, nPerm, exact, nullMaxMass, clusters (list of dict
    with mask/mass/pval/sig), sigMask
    """
    if rng is None:
        rng = np.random.default_rng()

    n_sub = data.shape[0]
    dev = data - chance_level

    df = n_sub - 1
    if tail == "right":
        tcrit = t_dist.ppf(1 - cluster_forming_alpha, df)
    elif tail == "left":
        tcrit = t_dist.ppf(cluster_forming_alpha, df)
    elif tail == "both":
        tcrit = t_dist.ppf(1 - cluster_forming_alpha / 2, df)
    else:
        raise ValueError("tail must be 'right', 'left', or 'both'")

    n_perm_exact = 2**n_sub
    if n_perm_exact <= n_perm_max:
        exact = True
        n_perm = n_perm_exact
        sign_mat = np.array(list(product([-1, 1], repeat=n_sub)))
    else:
        exact = False
        n_perm = n_perm_max
        sign_mat = rng.choice([-1, 1], size=(n_perm, n_sub))

    tobs = _tstat(dev)
    obs_clusters = _find_clusters(tobs, tcrit, tail)

    null_max_mass = np.zeros(n_perm)
    for p in range(n_perm):
        flips = sign_mat[p].reshape(n_sub, 1, 1)
        dev_perm = dev * flips
        tperm = _tstat(dev_perm)
        perm_clusters = _find_clusters(tperm, tcrit, tail)
        null_max_mass[p] = max((c["mass"] for c in perm_clusters), default=0.0)

    for c in obs_clusters:
        c["pval"] = (np.sum(null_max_mass >= c["mass"]) + 1) / (n_perm + 1)
        c["sig"] = bool(c["pval"] < cluster_alpha)

    sig_mask = np.zeros(tobs.shape, dtype=bool)
    for c in obs_clusters:
        if c["sig"]:
            sig_mask |= c["mask"]

    return {
        "nSub": n_sub,
        "chanceLevel": chance_level,
        "tail": tail,
        "clusterFormingAlpha": cluster_forming_alpha,
        "clusterAlpha": cluster_alpha,
        "tobs": tobs,
        "nPerm": n_perm,
        "exact": exact,
        "nullMaxMass": null_max_mass,
        "clusters": obs_clusters,
        "sigMask": sig_mask,
    }
