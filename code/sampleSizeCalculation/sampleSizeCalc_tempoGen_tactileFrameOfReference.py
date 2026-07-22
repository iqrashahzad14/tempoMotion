"""Sample size calculation: tactile frame-of-reference temporal generalization (bootstrap power).

Python/cluster port of sampleSizeCalc_tempoGen_tactileFrameOfReference.m -
same method, same parameters, parallelized with joblib across all
available cores.

For each of the 3 decodes (somatotopic, external, handPos) x 2 metrics
(accuracy, AUC) = 6 combinations, estimates statistical power to detect a
significant sign-flip cluster as a function of hypothetical sample size,
via case-resampling bootstrap.

Matrices are 56x56 (grid-subsampled by tgen_step=4 in the original
decoding script), so this is cheaper than the crossmodal (224x224)
version.

Requires tactileFoR_export.mat (see export_tempoGen_tactileFrameOfReference_for_python.m),
already copied alongside this script.

Usage: python sampleSizeCalc_tempoGen_tactileFrameOfReference.py [--n-jobs N]
"""

import argparse
import os
import time

import numpy as np
import scipy.io as sio

from fn_bootstrap_power import bootstrap_power

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-jobs", type=int, default=-1, help="cores for joblib.Parallel (-1 = all)")
    parser.add_argument("--data-dir", default=HERE, help="directory containing tactileFoR_export.mat")
    parser.add_argument("--out-dir", default=HERE, help="directory to write results into")
    args = parser.parse_args()

    n_jobs = args.n_jobs
    if n_jobs == -1 and "SLURM_CPUS_PER_TASK" in os.environ:
        n_jobs = int(os.environ["SLURM_CPUS_PER_TASK"])
    print(f"Using n_jobs={n_jobs}", flush=True)

    os.makedirs(args.out_dir, exist_ok=True)

    data = sio.loadmat(os.path.join(args.data_dir, "tactileFoR_export.mat"))
    var_names = [k for k in data.keys() if not k.startswith("__")]

    chance_level = 0.5
    tail = "right"
    cluster_forming_alpha = 0.05
    cluster_alpha = 0.05
    n_range = [6, 10, 20, 25, 30, 35, 40]
    n_bootstrap = 100
    n_perm_max = 100

    results = {}
    t_start = time.time()
    for var_name in sorted(var_names):
        stack = data[var_name]  # (nSub, T1, T2)
        print(f"\n=== {var_name}  (shape {stack.shape}) ===", flush=True)
        t0 = time.time()
        pr = bootstrap_power(
            stack,
            chance_level,
            n_range,
            n_bootstrap,
            tail=tail,
            cluster_forming_alpha=cluster_forming_alpha,
            cluster_alpha=cluster_alpha,
            n_perm_max=n_perm_max,
            n_jobs=n_jobs,
        )
        print(f"  {var_name}: {time.time() - t0:.1f} s, N80={pr['N80']}", flush=True)
        results[var_name] = pr

    elapsed_total = time.time() - t_start
    print(f"\nTotal compute time: {elapsed_total / 60:.1f} min", flush=True)

    out_npz = os.path.join(args.out_dir, "sampleSizeCalc_tempoGen_tactileFoR_python.npz")
    np.savez(
        out_npz,
        **{f"{k}__power": v["power"] for k, v in results.items()},
        **{f"{k}__Nrange": v["Nrange"] for k, v in results.items()},
        **{f"{k}__N80": v["N80"] for k, v in results.items()},
        elapsed_total=elapsed_total,
        n_range=n_range,
        n_bootstrap=n_bootstrap,
        n_perm_max=n_perm_max,
    )
    print(f"Saved results to {out_npz}")

    try:
        _plot_results(results, n_range, args.out_dir)
    except Exception as e:  # noqa: BLE001 - plotting is best-effort on a headless cluster node
        print(f"Plotting skipped ({e})")


def _plot_results(results, n_range, out_dir):
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    var_names = sorted(results.keys())
    n_rows = len(var_names)
    fig, axes = plt.subplots(n_rows, 1, figsize=(6, 2.2 * n_rows), squeeze=False)

    for i, var_name in enumerate(var_names):
        ax = axes[i, 0]
        pr = results[var_name]
        ax.plot(pr["Nrange"], pr["power"], "o-")
        ax.axhline(0.8, linestyle="--", color="k", linewidth=1)
        ax.axvline(pr["nSubOrig"], linestyle=":", color="r", linewidth=1)
        if not np.isnan(pr["N80"]):
            ax.axvline(pr["N80"], linestyle=":", color="g", linewidth=1)
            n80str = f"{pr['N80']:.0f}"
        else:
            n80str = f">{max(n_range)}"
        ax.set_ylim(0, 1)
        ax.set_xlabel("N subjects")
        ax.set_ylabel("Power")
        ax.set_title(f"{var_name} (N80={n80str})", fontsize=8)

    fig.suptitle("Sample size (bootstrap power) - tactile frame-of-reference temporal generalization [python]")
    fig.tight_layout()
    out_png = os.path.join(out_dir, "sampleSizeCalc_tempoGen_tactileFoR_python.png")
    fig.savefig(out_png, dpi=150)
    print(f"Saved plot to {out_png}")


if __name__ == "__main__":
    main()
