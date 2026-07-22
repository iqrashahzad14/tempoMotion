"""Shared plotting helper for sample-size (bootstrap power) result figures.

Used both by the driver scripts (sampleSizeCalc_tempoGen_*.py, right after
computing results) and by the replot_*.py scripts (reload a saved .npz, no
recomputation, just redraw - e.g. after a title/layout fix).
"""


def plot_power_grid(results, n_sub_orig, title, out_png):
    """results: dict var_name -> {'Nrange': ndarray, 'power': ndarray, 'N80': float}"""
    import numpy as np
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    var_names = sorted(results.keys())
    n_rows = len(var_names)
    fig, axes = plt.subplots(n_rows, 1, figsize=(7.5, 2.3 * n_rows))
    if n_rows == 1:
        axes = [axes]

    for ax, var_name in zip(axes, var_names):
        pr = results[var_name]
        n_range = pr["Nrange"]
        power = pr["power"]
        n80 = pr["N80"]

        ax.plot(n_range, power, "o-", color="#2a78d6", linewidth=1.8, markersize=5)
        ax.axhline(0.8, linestyle="--", color="#898781", linewidth=1)
        ax.axvline(n_sub_orig, linestyle=":", color="#e34948", linewidth=1)
        if not np.isnan(n80):
            ax.axvline(n80, linestyle=":", color="#008300", linewidth=1)
            n80str = f"{n80:.0f}"
        else:
            n80str = f">{max(n_range)}"

        ax.set_ylim(0, 1.05)
        ax.set_xlabel("N subjects")
        ax.set_ylabel("Power")
        label = var_name.replace("_", " ")
        ax.set_title(f"{label}  (N80={n80str})", fontsize=10, loc="left")
        ax.grid(alpha=0.3)

    fig.suptitle(title, fontsize=13, y=0.995)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(out_png, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved plot to {out_png}")
