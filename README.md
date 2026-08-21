# aurora_install_skill

## 中文说明

这个仓库不是只能给 Codex 用。它是一个 **Aurora 安装与运行知识库**，用于复现 Microsoft Aurora 在 Hygon DCU + Slurm 服务器上的安装、气象运行、CAMS 化学/空气污染运行和常见问题排查。

原始运行脚本和结果仓库在 [jingjing-2020/aurora-hygon-dcu](https://github.com/jingjing-2020/aurora-hygon-dcu)。这个仓库单独保存安装知识、助手说明和服务器 bootstrap 工具，避免把“怎么安装/怎么让助手使用”和“实际运行脚本/结果”混在一起。

### 三种使用入口

1. **Codex 使用**：`.agents/skills/aurora-install-skill/`
2. **Claude Code 使用**：`CLAUDE.md`
3. **普通用户在服务器上初始化环境**：`scripts/bootstrap_aurora_server.sh`

`.agents/skills` 只是 Codex 能直接调用的结构，不代表这份知识只能被 Codex 使用。Claude Code 可以读 `CLAUDE.md` 和同一份 reference；普通用户可以直接看 README 或运行 bootstrap 脚本。

### 普通用户怎么在服务器上一键初始化

在服务器登录节点上：

```bash
git clone https://github.com/jingjing-2020/aurora_install_skill.git
cd aurora_install_skill
cp config/aurora_server.env.example config/aurora_server.env
vi config/aurora_server.env
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env
```

这个脚本会做：

1. 读取你自己的服务器配置。
2. 尝试加载 module：compiler、OpenMPI、DTK、DTK PyTorch。
3. 创建隔离目录：`aurora_py38`、`cams_tools`、`hf_cache`。
4. 用 DTK Python 安装 Aurora 和下载工具。
5. 检查 `torch`、`aurora`、`cdsapi`、`huggingface_hub` 能否导入。

这个脚本不会做：

1. 不保存 ADS/CDS/Hugging Face 密钥。
2. 不自动下载 ERA5/CAMS 大数据。
3. 不自动提交完整科学预测作业。
4. 不替你决定真实 Slurm 分区名、GRES 名称、账号队列限制。

所以这里的“一键”指的是 **服务器环境 bootstrap 和导入检查**。真正跑 ERA5/CAMS 还需要去 `aurora-hygon-dcu` 使用对应脚本、数据和 Slurm 作业文件。

只检查当前环境、不安装包：

```bash
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env --only-checks
```

先预览会执行什么：

```bash
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env --dry-run
```

### Claude Code 怎么用

Claude Code 不需要 `.agents` 特殊机制也能用这个仓库。让它先读：

```text
CLAUDE.md
README.md
README_zh.md
.agents/skills/aurora-install-skill/references/aurora-hygon-dcu-install.md
```

然后它就可以按照同一套安装、气象、CAMS、Slurm、排错规则工作。

### Codex 怎么用

在 Codex 里可以这样问：

```text
Use $aurora-install-skill to show me how to reinstall Aurora on the Hygon DCU server and rerun the ERA5 and CAMS workflows.
```

或者中文：

```text
用 $aurora-install-skill 帮我检查 Aurora 服务器环境，并告诉我气象和化学两条流程分别怎么跑。
```

### 这个仓库覆盖什么

- Hygon DCU 运行环境：Slurm、DTK、HIP、DTK PyTorch、Python 3.8、Aurora。
- ERA5 气象流程：ERA5 NetCDF、`aurora.Batch`、`AuroraSmallPretrained`、一步天气预测。
- CAMS 化学/空气污染流程：ADS 下载、CAMS NetCDF、静态场、`AuroraAirPollution`、checkpoint、显存检查、PM/NO2/O3 输出。
- 验证步骤：Slurm 状态、退出码、输出文件、有限值检查、显存检查日志。
- 常见错误：Python 用错、MPI 缺失、Slurm GRES 错、DCU 不可见、Python 3.8 兼容问题、16 GiB 显存限制。

### 已验证的软件环境

```text
调度系统：Slurm
加速器：Hygon DCU
单卡显存：约 15.98 GiB
DTK：23.10
HIP：5.4.23453
PyTorch：2.1.0a0 DTK build
Python：3.8
Aurora：microsoft-aurora==2.0.0，并做过 Python 3.8 兼容修改
```

服务器 module 组合：

```bash
module purge
module load compiler/devtoolset/7.3.1
module load mpi/openmpi/4.0.4/gcc-7.3.1
module load compiler/dtk/23.10
module load apps/PyTorch/dtk-23.10/2.1.0a0
```

注意：Hygon DCU 底层是 HIP/DCU，但 PyTorch 里仍然用 `torch.cuda` 这套 API。

### 重要边界

这个仓库记录的是已经验证过的环境和可复现的重建模式，不是完整服务器 shell history。以后写文档或让助手操作时，要区分：

```text
已验证：真实跑通过、日志/输出确认过的内容。
重建模式：根据已验证环境整理出来的推荐安装命令。
未验证：换服务器、换 module、换 Python、换数据日期后的情况。
```

不要提交真实账号、服务器 IP、API key、token、私有路径、大数据文件、模型 checkpoint、Slurm 日志和作业号。

---

## English

Reusable installation and operation knowledge for the Microsoft Aurora workflow on a Slurm-managed Hygon DCU server.

This repository is not Codex-only. It provides three entry points:

- Codex skill: `.agents/skills/aurora-install-skill/`
- Claude Code project instructions: `CLAUDE.md`
- Human/server bootstrap: `scripts/bootstrap_aurora_server.sh`

The source workflow lives in [jingjing-2020/aurora-hygon-dcu](https://github.com/jingjing-2020/aurora-hygon-dcu). This repository keeps installation knowledge, assistant instructions, and reusable server setup separate so the workflow repository can stay focused on scripts, figures, and scientific results.

### What This Repository Covers

- Hygon DCU runtime setup: Slurm, DTK, HIP, DTK PyTorch, Python 3.8, and Aurora.
- ERA5 weather workflow: ERA5 NetCDF files, `aurora.Batch`, `AuroraSmallPretrained`, and one-step weather prediction.
- CAMS chemistry / air-pollution workflow: ADS access, CAMS NetCDF files, Aurora static fields, `AuroraAirPollution`, checkpoint handling, memory checks, and PM/NO2/O3 outputs.
- Verified execution checks: Slurm state, exit code, output files, finite-value checks, and memory-check logs.
- Common failure modes: wrong Python, missing MPI runtime, wrong Slurm GRES, no visible DCU, Python 3.8 compatibility issues, and 16 GiB memory limits.

### Repository Layout

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

### Codex Usage

In Codex, invoke:

```text
Use $aurora-install-skill to explain how to reinstall Aurora on my Hygon DCU server and rerun the ERA5 and CAMS workflows.
```

### Claude Code Usage

Claude Code should read `CLAUDE.md` first, then use the same reference material under `.agents/skills/aurora-install-skill/`. The files are plain Markdown, so they are not tied to Codex.

### Server Bootstrap Usage

On a server login node:

```bash
git clone https://github.com/jingjing-2020/aurora_install_skill.git
cd aurora_install_skill
cp config/aurora_server.env.example config/aurora_server.env
vi config/aurora_server.env
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env
```

The bootstrap script prepares isolated overlay directories, loads the configured module stack when `module` is available, installs Aurora/download helper packages, and runs import checks. It does not store credentials and it does not run the full ERA5 or CAMS forecasts; those still need the workflow scripts, data, accepted dataset terms, and cluster-specific Slurm settings.

### Important Boundary

This repository is based on verified project records, not a complete shell-history transcript. It preserves what was validated: module stack, Python layout, scripts, data flow, model choices, memory constraints, and output checks. When it gives rebuild commands that were inferred from the validated environment, it labels them as rebuild patterns.

Do not commit credentials, ADS/CDS keys, Hugging Face tokens, private server IPs, private paths, Slurm job IDs, checkpoints, NetCDF files, or generated outputs.
