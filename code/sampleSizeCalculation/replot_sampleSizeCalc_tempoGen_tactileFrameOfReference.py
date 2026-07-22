"""Regenerate the tempoGen_tactileFrameOfReference sample-size plot with cleaner titles.

Reloads the saved .npz (no recomputation) and redraws using
fn_plot_power_results.py's improved layout (fixes the suptitle
clipping/overlap in the original driver script's inline plotting code).
"""

import os

import numpy as np

from fn_plot_power_results import plot_power_grid

PROJECT_DIR = "/Users/iqrashahzad/Files/eeg/tempoMotion_ai2"
OUT_DIR = os.path.join(PROJECT_DIR, "outputs", "sampleSizeCalculation", "tempoGen_tactileFrameOfReference")

N_SUB_ORIG = 6  # all subject pools in this project are N=6


def main():
    npz_path = os.path.join(OUT_DIR, "sampleSizeCalc_tempoGen_tactileFoR_python.npz")
    data = np.load(npz_path)

    var_names = sorted({k.rsplit("__", 1)[0] for k in data.files if "__" in k})
    results = {
        v: {"Nrange": data[f"{v}__Nrange"], "power": data[f"{v}__power"], "N80": float(data[f"{v}__N80"])}
        for v in var_names
    }

    out_png = os.path.join(OUT_DIR, "sampleSizeCalc_tempoGen_tactileFoR_python.png")
    plot_power_grid(
        results, N_SUB_ORIG, "Sample size (bootstrap power): tactile frame-of-reference temporal generalization", out_png
    )


if __name__ == "__main__":
    main()
