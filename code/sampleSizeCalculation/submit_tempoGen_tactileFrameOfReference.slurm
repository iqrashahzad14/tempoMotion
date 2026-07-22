#!/bin/bash
#SBATCH --job-name=sampleSize_tactileFoR
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=iqra.shahzad@uclouvain.be
#
# Bootstrap power analysis for tempoGen_tactileFrameOfReference (6
# combinations, 56x56 grid-subsampled matrices - roughly 16x cheaper per
# pixel than the crossmodal 224x224 version, and half the combinations,
# so this finishes in minutes even at a small core count.
#
# Same notes as submit_tempoGen_crossmodal.slurm re: single-node joblib
# parallelism and the queue-wait-vs-run-time tradeoff behind keeping the
# core request small and leaning on --time=02:00:00 instead.

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
python sampleSizeCalc_tempoGen_tactileFrameOfReference.py --n-jobs "$SLURM_CPUS_PER_TASK" \
    --out-dir "$SLURM_SUBMIT_DIR/../../outputs/sampleSizeCalculation/tempoGen_tactileFrameOfReference"
