#!/bin/bash
#SBATCH --job-name=sampleSize_crossmodal
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=iqra.shahzad@uclouvain.be
#
# Bootstrap power analysis for tempoGen_crossmodal (12 combinations,
# 224x224 native-resolution matrices - the expensive one).
#
# NOTE: parallelism here is joblib (shared-memory, multiprocessing),
# which only uses CPUs WITHIN one node - hence --nodes=1/--ntasks=1 and
# scaling via --cpus-per-task, not multi-node MPI-style --ntasks=N.
#
# CORE COUNT TRADEOFF: total time-to-results = queue wait + run time, and
# on a shared cluster a bigger request can queue longer than the extra
# cores save. Compute here is cheap regardless (~7h of single-core-
# equivalent CPU-time), so this deliberately requests a small, backfill-
# friendly core count (8 -> ~52 min run time) and leans on a generous
# --time=02:00:00 ceiling instead of maximizing cores. Raise
# --cpus-per-task if you know the cluster is lightly loaded right now.

module load Python/3.12.3-GCCcore-13.3.0

cd "$SLURM_SUBMIT_DIR"

if [ ! -d venv ]; then
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
else
    source venv/bin/activate
fi

echo "Running on $(hostname), $SLURM_CPUS_PER_TASK CPUs allocated"
python sampleSizeCalc_tempoGen_crossmodal.py --n-jobs "$SLURM_CPUS_PER_TASK"
