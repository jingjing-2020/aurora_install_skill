---
name: aurora-install-skill
description: Reinstall, document, run, and troubleshoot the verified Microsoft Aurora workflow on the user's Slurm-managed Hygon DCU server. Use when the user asks about Aurora installation, Hygon DCU/DTK/PyTorch setup, ERA5 weather Batch creation, CAMS chemistry or air-pollution Batch creation, ADS/CDS/Hugging Face downloads, Slurm scripts, memory checks, near-surface NO2/O3 export, or reproducing the aurora-hygon-dcu workflow from the separate aurora_install_skill repository.
---

# Aurora Install Skill

## Overview

Use this skill to help the user rebuild or operate the Microsoft Aurora workflow validated on a Slurm-managed Hygon DCU cluster. Keep this skill separate from `jingjing-2020/aurora-hygon-dcu`; that repository is the workflow/result repository, while `aurora_install_skill` is the Codex instruction repository.

## First Checks

Start by establishing where the command should run:

1. Local Mac project.
2. Slurm login node.
3. Network-enabled download node.
4. DCU compute node allocated by Slurm.

Prefer evidence from the current repo, `jingjing-2020/aurora-hygon-dcu`, and `references/aurora-hygon-dcu-install.md`. State whether a command is a verified record or a rebuild pattern inferred from the verified environment.

Never expose or invent credentials, private server IPs, private paths, ADS/CDS keys, Hugging Face tokens, or Slurm job IDs.

## Workflow Choice

Use the ERA5 weather workflow when the user mentions ERA5, meteorology, weather, `AuroraSmallPretrained`, 2 m temperature, mean sea-level pressure, 500 hPa geopotential, or `prepare_aurora_era5_batch.py`.

Use the CAMS chemistry / air-pollution workflow when the user mentions CAMS, ADS, atmospheric chemistry, air quality, PM2.5, PM10, NO2, O3, `AuroraAirPollution`, `download_aurora_cams.py`, `prepare_aurora_cams_batch.py`, or `aurora-0.4-air-pollution.ckpt`.

Never reuse an ERA5 weather Batch as a CAMS air-pollution Batch. CAMS needs pollutant initial conditions, static fields, and the air-pollution checkpoint.

## Core Environment

The verified stack was:

- Slurm scheduler.
- Hygon DCU accelerator, about 15.98 GiB per device.
- DTK 23.10 and HIP 5.4.23453.
- DTK PyTorch 2.1.0a0 with Python 3.8.
- `microsoft-aurora==2.0.0` with Python 3.8 compatibility changes.
- Modules: `compiler/devtoolset/7.3.1`, `mpi/openmpi/4.0.4/gcc-7.3.1`, `compiler/dtk/23.10`, `apps/PyTorch/dtk-23.10/2.1.0a0`.

Important boundary: PyTorch still uses `torch.cuda` APIs on Hygon DCU/HIP. Check device visibility inside a Slurm job, not only on the login node.

## Detailed Reference

Read `references/aurora-hygon-dcu-install.md` when the user asks for:

- exact rebuild steps;
- what was installed;
- ERA5 weather commands;
- CAMS chemistry or air-pollution commands;
- Slurm templates;
- validation checklist;
- troubleshooting.

## Success Criteria

Do not call a run successful only because the job disappeared from `squeue`. Require:

- `sacct` shows `COMPLETED` and `ExitCode=0:0`;
- expected output exists and has plausible size;
- logs contain explicit completion text;
- model outputs pass finite-value checks;
- CAMS formal runs happen only after `MEMORY_CHECK=PASS`.

## Output Style

Answer in Chinese by default. Separate "安装了什么", "气象怎么跑", "化学/CAMS 怎么跑", and "怎么验证" into clear sections. Use placeholders for public-facing paths and credentials.
