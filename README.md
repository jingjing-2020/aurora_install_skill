# aurora_install_skill

Reusable installation and operation knowledge for the Microsoft Aurora workflow on a Slurm-managed Hygon DCU server.

This repository is not Codex-only. It provides three entry points:

- Codex skill: `.agents/skills/aurora-install-skill/`
- Claude Code project instructions: `CLAUDE.md`
- Human/server bootstrap: `scripts/bootstrap_aurora_server.sh`

The source workflow lives in [jingjing-2020/aurora-hygon-dcu](https://github.com/jingjing-2020/aurora-hygon-dcu). This repository keeps installation knowledge, assistant instructions, and reusable server setup separate so the workflow repository can stay focused on scripts, figures, and scientific results.

## What This Repository Covers

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
├── CLAUDE.md
├── config/
│   └── aurora_server.env.example
├── scripts/
│   └── bootstrap_aurora_server.sh
└── .agents/
    └── skills/
        └── aurora-install-skill/
            ├── SKILL.md
            ├── agents/
            │   └── openai.yaml
            └── references/
                └── aurora-hygon-dcu-install.md
```

## Codex Usage

In Codex, invoke:

```text
Use $aurora-install-skill to explain how to reinstall Aurora on my Hygon DCU server and rerun the ERA5 and CAMS workflows.
```

## Claude Code Usage

Claude Code should read `CLAUDE.md` first, then use the same reference material under `.agents/skills/aurora-install-skill/`. The files are plain Markdown, so they are not tied to Codex.

## Server Bootstrap Usage

On a server login node:

```bash
git clone https://github.com/jingjing-2020/aurora_install_skill.git
cd aurora_install_skill
cp config/aurora_server.env.example config/aurora_server.env
vi config/aurora_server.env
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env
```

The bootstrap script prepares isolated overlay directories, loads the configured module stack when `module` is available, installs Aurora/download helper packages, and runs import checks. It does not store credentials and it does not run the full ERA5 or CAMS forecasts; those still need the workflow scripts, data, accepted dataset terms, and cluster-specific Slurm settings.

## Important Boundary

This repository is based on verified project records, not a complete shell-history transcript. It preserves what was validated: module stack, Python layout, scripts, data flow, model choices, memory constraints, and output checks. When it gives rebuild commands that were inferred from the validated environment, it labels them as rebuild patterns.

Do not commit credentials, ADS/CDS keys, Hugging Face tokens, private server IPs, private paths, or Slurm job IDs.

See [README_zh.md](README_zh.md) for the detailed Chinese explanation.
