# Aurora 安装与运行说明

这个仓库不是只能给 Codex 用。它从原来的 [aurora-hygon-dcu](https://github.com/jingjing-2020/aurora-hygon-dcu) 项目里拆出来，专门保存 Aurora 在 Hygon DCU/Slurm 服务器上的安装、运行、排错知识。

现在它有三种入口：

1. **Codex 用**：`.agents/skills/aurora-install-skill/`
2. **Claude Code 用**：`CLAUDE.md`
3. **人自己在服务器上一键初始化**：`scripts/bootstrap_aurora_server.sh`

所以 `.agents/skills` 只是 Codex 能直接调用的结构，不代表这份知识只能被 Codex 使用。Claude Code 可以读 `CLAUDE.md` 和同一份 reference；普通用户也可以直接看 README 或运行 bootstrap 脚本。

## 这个仓库是做什么的

它不是模型代码仓库，而是一个 **安装知识库 + 助手说明 + 服务器 bootstrap 工具**，用来帮助你以后复现这套服务器工作：

1. 在 Slurm 管理的 Hygon DCU 服务器上准备 Microsoft Aurora 环境。
2. 运行 ERA5 气象预报流程。
3. 运行 CAMS 化学/空气污染流程。
4. 排查 DCU、DTK、PyTorch、MPI、Slurm、显存和下载问题。
5. 解释哪些结果已经验证过，哪些只是重装时的推荐做法。

## 和 aurora-hygon-dcu 的关系

`aurora-hygon-dcu` 应该继续保持为实际项目仓库，包含：

- Aurora 运行脚本。
- ERA5 和 CAMS 处理脚本。
- 图片和结果说明。
- 技术 README。

`aurora_install_skill` 只放：

- 给 Codex 使用的 `.agents/skills/aurora-install-skill/`。
- 给 Claude Code 使用的 `CLAUDE.md`。
- 给人/服务器使用的 `scripts/bootstrap_aurora_server.sh` 和配置模板。
- README 和安装/运行说明。

这样以后你问 Codex “Aurora 怎么装”“CAMS 怎么跑”“Slurm 报错怎么办”，Codex 可以直接使用这个 skill，而不是每次重新读散落的聊天记录。

## 文件结构

```text
aurora_install_skill/
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

## 普通用户怎么在服务器上一键初始化

在服务器登录节点上：

```bash
git clone https://github.com/jingjing-2020/aurora_install_skill.git
cd aurora_install_skill
cp config/aurora_server.env.example config/aurora_server.env
vi config/aurora_server.env
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env
```

这个脚本会做这些事：

1. 读取你自己的服务器配置。
2. 尝试加载 module：compiler、OpenMPI、DTK、DTK PyTorch。
3. 创建隔离目录：`aurora_py38`、`cams_tools`、`hf_cache`。
4. 用 DTK Python 安装 Aurora 和下载工具。
5. 检查 `torch`、`aurora`、`cdsapi`、`huggingface_hub` 能否导入。

它不会做这些事：

1. 不保存 ADS/CDS/Hugging Face 密钥。
2. 不自动下载 ERA5/CAMS 大数据。
3. 不自动提交完整科学预测作业。
4. 不替你决定真实 Slurm 分区名、GRES 名称、账号队列限制。

所以这里的“一键”指的是 **服务器环境 bootstrap 和导入检查**。真正跑 ERA5/CAMS 还需要去 `aurora-hygon-dcu` 使用对应脚本、数据和 Slurm 作业文件。

如果只想检查当前环境，不安装包：

```bash
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env --only-checks
```

如果想先看它会执行什么：

```bash
bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env --dry-run
```

## Claude Code 怎么用

Claude Code 不需要 `.agents` 特殊机制也能用这个仓库。让它先读：

```text
CLAUDE.md
README_zh.md
.agents/skills/aurora-install-skill/references/aurora-hygon-dcu-install.md
```

然后它就可以按照同一套安装、气象、CAMS、Slurm、排错规则工作。

## 已验证的软件环境

这套流程是在下面环境中验证过的：

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

## 气象部分怎么跑

ERA5 气象流程是：

```text
ERA5 NetCDF
-> prepare_aurora_era5_batch.py
-> aurora.Batch
-> AuroraSmallPretrained
-> 一步全球气象预测
-> 温度、气压、500 hPa 位势高度图
```

输入变量包括：

```text
地面变量：2t, 10u, 10v, msl
气压层变量：t, u, v, q, z
静态变量：z, slt, lsm
气压层：50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000 hPa
```

构建 Batch 的典型命令：

```bash
python scripts/prepare_aurora_era5_batch.py \
  --date 2023-01-01 \
  --skip-download \
  --download-dir <ERA5_WORKDIR>/ERA5_data/aurora_era5 \
  --output <ERA5_WORKDIR>/outputs/aurora/era5_2023-01-01_batch.pt
```

为什么用 `AuroraSmallPretrained`：

- 完整 `AuroraPretrained` 放不进单张约 16 GiB 的 DCU。
- 申请两张 DCU 不会自动把显存合并。
- 当前验证过的一步天气预测使用小模型加混合精度。

## 化学 / 空气污染部分怎么跑

CAMS 化学/污染流程和 ERA5 不同，不能直接拿 ERA5 Batch 去跑。

流程是：

```text
CAMS ADS 下载
-> CAMS surface-level NetCDF
-> CAMS atmospheric NetCDF
-> Aurora air-pollution static pickle
-> prepare_aurora_cams_batch.py
-> AuroraAirPollution Batch
-> 显存检查
-> AuroraAirPollution 一步预测
-> PM2.5、PM10、NO2、O3 导出和绘图
```

下载前需要：

1. 有 Copernicus ADS 账号。
2. 在网页接受 CAMS 数据集条款。
3. 配置 ADS API Key。
4. 在能联网的节点下载，不要在无外网的计算节点下载。

典型下载命令：

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

正式预测前先跑显存检查：

```bash
sbatch aurora_air_pollution_memory.slurm
grep -E 'MEMORY_CHECK|Peak|Forecast time|OOM' air_mem_<job-id>.out
```

只有看到：

```text
MEMORY_CHECK=PASS
```

再提交正式预测：

```bash
sbatch aurora_air_pollution_run.slurm
```

## 怎么验证成功

不能只看作业从 `squeue` 消失。至少检查：

```bash
sacct -j <JOB_ID> --format=JobID,JobName,Partition,State,Elapsed,ExitCode
ls -lh <EXPECTED_OUTPUT>
grep -E 'complete|Forecast complete|MEMORY_CHECK|Outputs finite' *.out
cat *.err
```

成功标准：

```text
State=COMPLETED
ExitCode=0:0
输出文件存在
日志有完成信息
数值检查没有 NaN/Inf
```

## 最常见的问题

| 问题 | 原因 | 处理 |
| --- | --- | --- |
| `No module named cdsapi` | 用错 Python 或没有加 tools 路径 | 使用 `<CONDA_AURORA>` 或设置 `<CAMS_TOOLS>` 到 `PYTHONPATH` |
| `libmpi.so.40` 找不到 | MPI module 没加载 | 先加载 compiler 和 OpenMPI，再加载 DTK/PyTorch |
| `torch.cuda.is_available() == False` | 登录节点没分配 DCU | 到 Slurm 计算节点测试 |
| `Invalid generic resource specification` | GRES 名称不对 | 用 `scontrol show node` 查真实 GRES |
| CAMS OOM | 全局 Batch 和模型太大 | 用 autocast、`model.backbone.half()`，先跑 memory check |
| Hugging Face 下载失败 | 计算节点无网络 | 在联网节点下载，正式作业设 `HF_HUB_OFFLINE=1` |
| NO2/O3 含义不清 | 不是地面直接输出 | 标成“地形以上最低可用压力层近地面近似” |

## Codex 使用方式

在 Codex 里可以这样问：

```text
Use $aurora-install-skill to show me how to reinstall Aurora on the Hygon DCU server and rerun the ERA5 and CAMS workflows.
```

或者中文：

```text
用 $aurora-install-skill 帮我检查 Aurora 服务器环境，并告诉我气象和化学两条流程分别怎么跑。
```

## 重要边界

这个仓库记录的是已经验证过的环境和可复现的重建模式，不是完整服务器 shell history。以后写文档或让助手操作时，要区分：

```text
已验证：真实跑通过、日志/输出确认过的内容。
重建模式：根据已验证环境整理出来的推荐安装命令。
未验证：换服务器、换 module、换 Python、换数据日期后的情况。
```

不要提交真实账号、服务器 IP、API key、token、私有路径、大数据文件、模型 checkpoint、Slurm 日志和作业号。
