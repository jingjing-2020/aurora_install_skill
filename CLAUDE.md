# Claude Code Instructions

This repository is a reusable Aurora installation and operation knowledge base. It is not limited to Codex.

## How To Use This Repository

When a user asks about installing, rerunning, or debugging Aurora on the Hygon DCU server:

1. Read `README_zh.md` if the user is working in Chinese.
2. Read `.agents/skills/aurora-install-skill/SKILL.md` for routing rules and safety boundaries.
3. Read `.agents/skills/aurora-install-skill/references/aurora-hygon-dcu-install.md` for exact environment, Slurm, ERA5, CAMS, and troubleshooting details.
4. Use `scripts/bootstrap_aurora_server.sh` when the user wants a server-side bootstrap helper.

## Response Rules

- Answer in Chinese when the user writes in Chinese.
- Separate verified facts from rebuild patterns.
- Do not invent server paths, IP addresses, job IDs, credentials, ADS/CDS keys, or Hugging Face tokens.
- Do not commit generated data, checkpoints, NetCDF files, Slurm logs, API keys, or private server configuration.
- Keep `jingjing-2020/aurora-hygon-dcu` as the workflow/result repository. Keep this repository focused on install knowledge, assistant instructions, and reusable bootstrap helpers.

## Server Bootstrap

For a human or another agent installing on the server:

```bash
git clone https://github.com/jingjing-2020/aurora_install_skill.git
cd aurora_install_skill
cp config/aurora_server.env.example config/aurora_server.env
vi config/aurora_server.env
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env
```

The bootstrap script prepares the Python overlay directories, loads the configured module stack, installs Aurora/download tools, and runs import checks. It does not run full scientific forecasts and it does not store credentials.

