# Aurora Hygon DCU Install And Run Reference

Use this reference when the user asks for detailed steps to install, rerun, or troubleshoot the Aurora workflow on the Hygon DCU server.

## Contents

1. Evidence boundary
2. What was installed
3. Directory layout
4. Rebuild pattern
5. ERA5 weather workflow
6. CAMS chemistry / air-pollution workflow
7. Slurm templates
8. Verification checklist
9. Troubleshooting table

## 1. Evidence Boundary

The verified project records preserve the runtime stack, module set, scripts, data flow, output files, memory behavior, and successful one-step forecasts. They do not preserve a complete shell-history transcript of every original install command. When reconstructing an environment, label commands as a rebuild pattern unless the exact command appears in the source workflow.

Do not publish real usernames, IP addresses, API keys, tokens, private server paths, or Slurm job IDs. Use placeholders such as `<SERVER_ROOT>`, `<ERA5_WORKDIR>`, `<CAMS_WORKDIR>`, `<DTK_PYTHON>`, and `<HF_CACHE>`.

## 2. What Was Installed

Verified server stack:

```text
Scheduler: Slurm
Accelerator: Hygon DCU
Per-device memory: about 15.98 GiB
DTK: 23.10
HIP: 5.4.23453
PyTorch: 2.1.0a0 DTK build
Python: 3.8
Aurora: microsoft-aurora==2.0.0 with Python 3.8 compatibility changes
```

Verified module sequence:

```bash
module purge
module load compiler/devtoolset/7.3.1
module load mpi/openmpi/4.0.4/gcc-7.3.1
module load compiler/dtk/23.10
module load apps/PyTorch/dtk-23.10/2.1.0a0
```

Observed Python/tool locations:

```text
<DTK_PYTHON>     /public/software/apps/DeepLearning/PyTorch/pytorch-2.1.0-dtk23.10/build/bin/python3
<AURORA_PY38>    <SERVER_ROOT>/aurora_py38
<CAMS_TOOLS>     <SERVER_ROOT>/cams_tools
<CONDA_AURORA>   <SERVER_ROOT>/conda_envs/aurora/bin/python
<HF_CACHE>       <SERVER_ROOT>/hf_cache/hub
```

Packages used by the workflow:

```text
Core model runtime: torch, microsoft-aurora
ERA5/CAMS preparation: xarray, netcdf4, numpy, torch, aurora
Downloads: cdsapi, huggingface_hub, requests
Plotting: matplotlib, cartopy, numpy
```

`torch.cuda` APIs are expected even on Hygon DCU because PyTorch exposes HIP devices through CUDA-compatible names.

## 3. Directory Layout

Weather workflow:

```text
<SERVER_ROOT>/aurora_data/
  era5_2023-01-01_batch.pt
  era5_2023-01-01_pred_step1.pt
  run_aurora.py
  run.slurm
```

Chemistry / air-pollution workflow:

```text
<SERVER_ROOT>/aurora_air_pollution/
  scripts/
  data/cams/
    2022-06-11-cams.nc.zip
    2022-06-11-cams-surface-level.nc
    2022-06-11-cams-atmospheric.nc
    aurora-0.4-air-pollution-static.pickle
  data/cams_2022-06-11_batch.pt
  checkpoints/aurora-0.4-air-pollution.ckpt
  outputs/
```

Network downloads were run on a network-enabled node in the verified workflow. Slurm jobs were submitted from a login node. Verify the equivalent hostnames on the current cluster.

## 4. Rebuild Pattern

Check the module stack first:

```bash
module purge
module load compiler/devtoolset/7.3.1
module load mpi/openmpi/4.0.4/gcc-7.3.1
module load compiler/dtk/23.10
module load apps/PyTorch/dtk-23.10/2.1.0a0

which python
python --version
python -c 'import torch; print(torch.__file__); print(torch.__version__); print(torch.version.hip)'
```

If the shell still uses the wrong Python, use the DTK Python absolute path:

```bash
DTK_PY=<DTK_PYTHON>
"$DTK_PY" --version
"$DTK_PY" -c 'import torch; print(torch.__file__); print(torch.version.hip)'
```

Keep Aurora and download tools isolated:

```bash
mkdir -p <SERVER_ROOT>/aurora_py38 <SERVER_ROOT>/cams_tools <HF_CACHE>
```

Install Aurora into the Python 3.8 overlay:

```bash
"$DTK_PY" -m pip install --target <SERVER_ROOT>/aurora_py38 microsoft-aurora==2.0.0
export PYTHONPATH=<SERVER_ROOT>/aurora_py38:${PYTHONPATH:-}
"$DTK_PY" -c 'import aurora; print(aurora.__file__)'
```

The verified environment needed Python 3.8 compatibility edits for newer Python syntax such as `str.removeprefix`, `tuple[...]`, and `dict[...]`.

Install download-only tools separately if changing the DTK environment is risky:

```bash
"$DTK_PY" -m pip install --target <SERVER_ROOT>/cams_tools cdsapi huggingface_hub requests
export PYTHONPATH=<SERVER_ROOT>/cams_tools:${PYTHONPATH:-}
"$DTK_PY" -c 'import cdsapi, huggingface_hub; print("download tools ok")'
```

For CPU preparation and plotting, verify the actual Python has:

```text
xarray, netcdf4, numpy, matplotlib, cartopy
```

## 5. ERA5 Weather Workflow

ERA5 creates a weather Batch. It does not contain pollution initial conditions.

Input variables:

```text
Surface: 2t, 10u, 10v, msl
Atmospheric: t, u, v, q, z
Static: z, slt, lsm
Pressure levels: 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000 hPa
```

Prepare or reuse:

```text
static.nc
2023-01-01-surface-level.nc
2023-01-01-atmospheric.nc
```

Build the Batch:

```bash
python scripts/prepare_aurora_era5_batch.py \
  --date 2023-01-01 \
  --skip-download \
  --download-dir <ERA5_WORKDIR>/ERA5_data/aurora_era5 \
  --output <ERA5_WORKDIR>/outputs/aurora/era5_2023-01-01_batch.pt
```

If downloading from CDS, remove `--skip-download`, accept CDS dataset terms first, and keep the CDS API key outside the repository.

Use `AuroraSmallPretrained` on a 16 GiB DCU:

```python
from aurora import AuroraSmallPretrained

model = AuroraSmallPretrained(
    autocast=True,
    autocast_dtype=torch.float16,
    use_fp16_safe_attention=True,
)
model.autocast_encoder = True
model.autocast_backbone = True
model.autocast_decoder = True
```

Verified result:

```text
Input: 2023-01-01 00:00 and 06:00 UTC
Forecast: 2023-01-01 12:00 UTC
Grid: 720 x 1440
Surface prediction shape: (1, 1, 720, 1440)
Pressure-level prediction shape: (1, 1, 13, 720, 1440)
```

## 6. CAMS Chemistry / Air-Pollution Workflow

CAMS uses different data from ERA5. Do not use an ERA5 Batch for `AuroraAirPollution`.

Before downloading:

1. Create or use a Copernicus ADS account.
2. Accept the CAMS global atmospheric composition forecast dataset terms.
3. Provide the ADS API key through an environment variable or protected config.

Use:

```bash
read -s -p "ADS API Key: " ADS_API_KEY
export ADS_API_KEY
```

Run network downloads on the network-enabled node:

```bash
ssh <DOWNLOAD_NODE>
cd <CAMS_WORKDIR>

PY=<CONDA_AURORA>
export PYTHONPATH=<SERVER_ROOT>/cams_tools:${PYTHONPATH:-}
export HF_HUB_CACHE=<HF_CACHE>
export HF_HUB_DOWNLOAD_TIMEOUT=600

"$PY" scripts/download_aurora_cams.py \
  --date 2022-06-11 \
  --download-dir <CAMS_WORKDIR>/data/cams \
  --hf-cache-dir "$HF_HUB_CACHE"
```

Download the air-pollution checkpoint on a network-enabled node:

```bash
HF_HUB_DOWNLOAD_TIMEOUT=600 hf download \
  microsoft/aurora \
  aurora-0.4-air-pollution.ckpt \
  --cache-dir <HF_CACHE>
```

Compute jobs should use offline mode:

```bash
export HF_HUB_CACHE=<HF_CACHE>
export HF_HUB_OFFLINE=1
```

Build the CAMS Batch:

```bash
cd <CAMS_WORKDIR>
sbatch aurora_cams_prepare.slurm
squeue -u "$USER"
```

Equivalent direct command:

```bash
"$PY" scripts/prepare_aurora_cams_batch.py \
  --date 2022-06-11 \
  --input-dir <CAMS_WORKDIR>/data/cams \
  --output <CAMS_WORKDIR>/data/cams_2022-06-11_batch.pt
```

Run the real memory check first:

```bash
sbatch aurora_air_pollution_memory.slurm
grep -E 'MEMORY_CHECK|Peak|Forecast time|OOM' air_mem_<job-id>.out
cat air_mem_<job-id>.err
```

Interpretation:

```text
MEMORY_CHECK=PASS       one real step fits
MEMORY_CHECK=OOM        one 16 GiB DCU is insufficient
MEMORY_CHECK=NO_DEVICE  Slurm did not expose a usable DCU
```

Only after `MEMORY_CHECK=PASS`, run:

```bash
sbatch aurora_air_pollution_run.slurm
squeue -u "$USER"
```

Verified result:

```text
Input: 2022-06-11 00:00 and 12:00 UTC
Forecast: 2022-06-12 00:00 UTC
Model: AuroraAirPollution
Checkpoint: aurora-0.4-air-pollution.ckpt
Peak inference memory: about 14.49 GiB
One-step runtime: about 30.60 s
```

Air-pollution precision settings:

```python
model = AuroraAirPollution(
    autocast=True,
    autocast_dtype=torch.float16,
    use_fp16_safe_attention=True,
)
model.autocast_encoder = True
model.autocast_backbone = True
model.autocast_decoder = True
model.load_checkpoint_local(str(checkpoint))
model.backbone.half()
```

Export plotting arrays:

```bash
"$DTK_PY" scripts/export_aurora_air_pollution_near_surface_maps.py \
  <CAMS_WORKDIR>/outputs/cams_air_pollution_step01_20220612T0000Z.pt \
  --output <CAMS_WORKDIR>/outputs/cams_air_pollution_step01_near_surface_maps.npz
```

Scientific labeling:

```text
PM2.5 and PM10: direct surface outputs, converted from kg m-3 to ug m-3.
NO2 and O3: lowest available pressure level above terrain, converted from kg kg-1 to ug m-3.
```

Do not call NO2 and O3 true ground-monitor concentrations unless station-height vertical matching has been added.

## 7. Slurm Templates

Base DCU job:

```bash
#!/bin/bash
#SBATCH --partition=dcu
#SBATCH --gres=dcu:Hygon:1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=02:00:00
#SBATCH --output=run_%j.out
#SBATCH --error=run_%j.err

set -euo pipefail

module purge
module load compiler/devtoolset/7.3.1
module load mpi/openmpi/4.0.4/gcc-7.3.1
module load compiler/dtk/23.10
module load apps/PyTorch/dtk-23.10/2.1.0a0

export PYTHONPATH=<SERVER_ROOT>/aurora_py38:${PYTHONPATH:-}
export PYTHONNOUSERSITE=1
export PYTHONUNBUFFERED=1
export HF_HUB_CACHE=<HF_CACHE>
export HF_HUB_OFFLINE=1
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:128

<DTK_PYTHON> -u run_model.py
```

Base CPU preparation job:

```bash
#!/bin/bash
#SBATCH --partition=cpu_parallel
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --output=prep_%j.out
#SBATCH --error=prep_%j.err

set -euo pipefail

PY=<CONDA_AURORA>
export PYTHONPATH=<SERVER_ROOT>/cams_tools:${PYTHONPATH:-}
export PYTHONUNBUFFERED=1

cd <WORKDIR>
"$PY" scripts/prepare_aurora_cams_batch.py \
  --date 2022-06-11 \
  --input-dir <WORKDIR>/data/cams \
  --output <WORKDIR>/data/cams_2022-06-11_batch.pt
```

Confirm cluster-specific names:

```bash
sinfo -s
scontrol show node | grep -i gres
sbatch --test-only run.slurm
```

## 8. Verification Checklist

Before model jobs:

```bash
module list
<DTK_PYTHON> --version
<DTK_PYTHON> -c 'import torch; print(torch.__file__); print(torch.version.hip)'
<DTK_PYTHON> -c 'import aurora; print(aurora.__file__)'
```

Inside Slurm:

```python
import torch
print(torch.cuda.is_available())
print(torch.cuda.device_count())
print(torch.cuda.get_device_name(0))
```

After jobs:

```bash
sacct -j <JOB_ID> --format=JobID,JobName,Partition,State,Elapsed,ExitCode
ls -lh <EXPECTED_OUTPUT>
grep -E 'complete|Forecast complete|MEMORY_CHECK|Outputs finite' *.out
cat *.err
```

Success requires:

```text
State=COMPLETED
ExitCode=0:0
Output file exists and has plausible size
Logs include explicit completion
Finite-value check passed
```

## 9. Troubleshooting Table

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `No module named cdsapi` | Wrong Python or missing isolated tools | Use `<CONDA_AURORA>` or add `<CAMS_TOOLS>` to `PYTHONPATH` |
| `libmpi.so.40` missing | MPI runtime module not loaded | Load compiler and OpenMPI modules before DTK PyTorch |
| `torch.cuda.is_available() == False` | Running on login node or no DCU allocated | Test inside Slurm with correct GRES |
| `Invalid generic resource specification` | Wrong GRES name | Inspect `scontrol show node` and adjust `--gres` |
| `No HIP GPUs are available` | Slurm/device/runtime mismatch | Check GRES allocation, `/dev/kfd`, module stack, and device permissions |
| Python 3.8 import errors in Aurora | Package used Python 3.9+ syntax | Apply Python 3.8 compatibility edits or use a compatible Python stack |
| Full ERA5 model OOM | Full model exceeds 16 GiB | Use `AuroraSmallPretrained` with mixed precision |
| CAMS model OOM | Air-pollution model and global Batch too large | Use full autocast and `model.backbone.half()`; verify with memory job |
| Hugging Face download fails on compute node | Compute node has no network | Download on network node, then set `HF_HUB_OFFLINE=1` for jobs |
| ADS download stalls or fails | ADS request queue, missing terms, or network node issue | Accept dataset terms, use network-enabled node, keep `nohup` log |
| PM values negative | Model output not constrained nonnegative | Preserve raw values; clip only for visualization and document it |
| NO2/O3 map meaning unclear | Pressure-level approximation | Label as near-surface lowest pressure level above terrain |
