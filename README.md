# aurora_install_skill

Codex skill and reusable notes for reinstalling, rerunning, and troubleshooting the Microsoft Aurora workflow on a Slurm-managed Hygon DCU server.

The source workflow lives in [jingjing-2020/aurora-hygon-dcu](https://github.com/jingjing-2020/aurora-hygon-dcu). This repository keeps the Codex-facing skill separate so the workflow repository stays focused on scripts, figures, and scientific results.

## What This Skill Covers

- Hygon DCU runtime setup: Slurm, DTK, HIP, DTK PyTorch, Python 3.8, and Aurora.
- ERA5 weather workflow: ERA5 NetCDF files, `aurora.Batch`, `AuroraSmallPretrained`, and one-step weather prediction.
- CAMS chemistry / air-pollution workflow: ADS access, CAMS NetCDF files, Aurora static fields, `AuroraAirPollution`, checkpoint handling, memory checks, and PM/NO2/O3 outputs.
- Verified execution checks: Slurm state, exit code, output files, finite-value checks, and memory-check logs.
- Common failure modes: wrong Python, missing MPI runtime, wrong Slurm GRES, no visible DCU, Python 3.8 compatibility issues, and 16 GiB memory limits.

## Repository Layout

```text
.
├── README.md
├── README_zh.md
└── .agents/
    └── skills/
        └── aurora-install-skill/
            ├── SKILL.md
            ├── agents/
            │   └── openai.yaml
            └── references/
                └── aurora-hygon-dcu-install.md
```

## Using The Skill

In Codex, invoke:

```text
Use $aurora-install-skill to explain how to reinstall Aurora on my Hygon DCU server and rerun the ERA5 and CAMS workflows.
```

The skill first decides whether the user is asking about:

- Installing or rebuilding the Aurora environment.
- Running the ERA5 weather workflow.
- Running the CAMS chemistry / air-pollution workflow.
- Debugging Slurm, DCU, Python, checkpoint, or output problems.

## Important Boundary

This skill is based on verified project records, not a complete shell-history transcript. It preserves what was validated: module stack, Python layout, scripts, data flow, model choices, memory constraints, and output checks. When it gives rebuild commands that were inferred from the validated environment, it labels them as rebuild patterns.

Do not commit credentials, ADS/CDS keys, Hugging Face tokens, private server IPs, private paths, or Slurm job IDs.

See [README_zh.md](README_zh.md) for the detailed Chinese explanation.
