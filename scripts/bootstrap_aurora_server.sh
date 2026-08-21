#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=""
DRY_RUN=0
SKIP_INSTALL=0
ONLY_CHECKS=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/bootstrap_aurora_server.sh [options]

Options:
  --config PATH     Source a server-specific config file.
  --dry-run         Print commands without executing them.
  --skip-install    Create directories and run checks, but do not run pip install.
  --only-checks     Skip directory creation and installs; only load modules and run import checks.
  --help            Show this help text.

Typical use:
  cp config/aurora_server.env.example config/aurora_server.env
  vi config/aurora_server.env
  bash scripts/bootstrap_aurora_server.sh --config config/aurora_server.env
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      if [[ -z "$CONFIG_FILE" ]]; then
        echo "ERROR: --config needs a path" >&2
        exit 2
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    --only-checks)
      ONLY_CHECKS=1
      SKIP_INSTALL=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config file not found: $CONFIG_FILE" >&2
    exit 2
  fi
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

SERVER_ROOT="${SERVER_ROOT:-${HOME}/aurora_server}"
DTK_PYTHON="${DTK_PYTHON:-/public/software/apps/DeepLearning/PyTorch/pytorch-2.1.0-dtk23.10/build/bin/python3}"
AURORA_PY38="${AURORA_PY38:-${SERVER_ROOT}/aurora_py38}"
CAMS_TOOLS="${CAMS_TOOLS:-${SERVER_ROOT}/cams_tools}"
HF_CACHE="${HF_CACHE:-${SERVER_ROOT}/hf_cache/hub}"

LOAD_MODULES="${LOAD_MODULES:-1}"
AURORA_MODULES="${AURORA_MODULES:-compiler/devtoolset/7.3.1 mpi/openmpi/4.0.4/gcc-7.3.1 compiler/dtk/23.10 apps/PyTorch/dtk-23.10/2.1.0a0}"

INSTALL_AURORA="${INSTALL_AURORA:-1}"
INSTALL_DOWNLOAD_TOOLS="${INSTALL_DOWNLOAD_TOOLS:-1}"
RUN_IMPORT_CHECKS="${RUN_IMPORT_CHECKS:-1}"
AURORA_VERSION="${AURORA_VERSION:-2.0.0}"
AURORA_BASE_PACKAGE="${AURORA_BASE_PACKAGE:-microsoft-aurora==${AURORA_VERSION}}"
AURORA_BASE_PIP_FLAGS="${AURORA_BASE_PIP_FLAGS:---upgrade --no-deps}"
AURORA_EXTRA_PACKAGES="${AURORA_EXTRA_PACKAGES:-xarray netCDF4 numpy pandas einops timm safetensors huggingface_hub requests}"
DOWNLOAD_TOOL_PACKAGES="${DOWNLOAD_TOOL_PACKAGES:-cdsapi huggingface_hub requests}"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

print_cmd() {
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

run_cmd() {
  print_cmd "$@"
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  "$@"
}

try_init_modules() {
  if command -v module >/dev/null 2>&1; then
    return 0
  fi

  local init_file
  for init_file in \
    /etc/profile.d/modules.sh \
    /usr/share/Modules/init/bash \
    /usr/local/Modules/init/bash; do
    if [[ -r "$init_file" ]]; then
      # shellcheck source=/dev/null
      source "$init_file"
      break
    fi
  done
}

load_modules() {
  if [[ "$LOAD_MODULES" != "1" ]]; then
    log "Skipping module load because LOAD_MODULES=$LOAD_MODULES"
    return 0
  fi

  log "Loading module stack"
  try_init_modules

  if ! command -v module >/dev/null 2>&1; then
    warn "module command is not available in this shell; continuing without module load"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "+ module purge"
    for module_name in $AURORA_MODULES; do
      echo "+ module load ${module_name}"
    done
    return 0
  fi

  module purge
  for module_name in $AURORA_MODULES; do
    module load "$module_name"
  done
  module list
}

ensure_dirs() {
  log "Creating isolated Aurora directories"
  run_cmd mkdir -p "$SERVER_ROOT" "$AURORA_PY38" "$CAMS_TOOLS" "$HF_CACHE"
}

check_python() {
  log "Checking DTK Python and PyTorch"

  if [[ "$DRY_RUN" != "1" && ! -x "$DTK_PYTHON" ]]; then
    echo "ERROR: DTK_PYTHON is not executable: $DTK_PYTHON" >&2
    echo "Edit config/aurora_server.env to the Python path provided by your cluster." >&2
    exit 3
  fi

  run_cmd "$DTK_PYTHON" --version
  run_cmd "$DTK_PYTHON" -c 'import sys; print("python:", sys.executable); import torch; print("torch:", torch.__version__); print("torch file:", torch.__file__); print("hip:", torch.version.hip)'
}

install_aurora() {
  if [[ "$SKIP_INSTALL" == "1" || "$INSTALL_AURORA" != "1" ]]; then
    log "Skipping Aurora install"
    return 0
  fi

  log "Installing Aurora into AURORA_PY38"
  read -r -a base_flags <<< "$AURORA_BASE_PIP_FLAGS"
  read -r -a extra_packages <<< "$AURORA_EXTRA_PACKAGES"

  run_cmd "$DTK_PYTHON" -m pip install "${base_flags[@]}" --target "$AURORA_PY38" "$AURORA_BASE_PACKAGE"

  if [[ "${#extra_packages[@]}" -gt 0 ]]; then
    run_cmd "$DTK_PYTHON" -m pip install --upgrade --target "$AURORA_PY38" "${extra_packages[@]}"
  fi
}

install_download_tools() {
  if [[ "$SKIP_INSTALL" == "1" || "$INSTALL_DOWNLOAD_TOOLS" != "1" ]]; then
    log "Skipping download-tool install"
    return 0
  fi

  log "Installing CDS/ADS/Hugging Face helper tools"
  read -r -a download_packages <<< "$DOWNLOAD_TOOL_PACKAGES"
  if [[ "${#download_packages[@]}" -gt 0 ]]; then
    run_cmd "$DTK_PYTHON" -m pip install --upgrade --target "$CAMS_TOOLS" "${download_packages[@]}"
  fi
}

run_import_checks() {
  if [[ "$RUN_IMPORT_CHECKS" != "1" ]]; then
    log "Skipping import checks because RUN_IMPORT_CHECKS=$RUN_IMPORT_CHECKS"
    return 0
  fi

  log "Running Aurora and download-tool import checks"
  local combined_pythonpath
  combined_pythonpath="${AURORA_PY38}:${CAMS_TOOLS}:${PYTHONPATH:-}"

  run_cmd env \
    PYTHONPATH="$combined_pythonpath" \
    PYTHONNOUSERSITE=1 \
    HF_HUB_CACHE="$HF_CACHE" \
    AURORA_PY38="$AURORA_PY38" \
    CAMS_TOOLS="$CAMS_TOOLS" \
    "$DTK_PYTHON" -c 'import os; import torch; torch_file = os.path.abspath(torch.__file__); overlays = [os.path.abspath(os.environ["AURORA_PY38"]), os.path.abspath(os.environ["CAMS_TOOLS"])]; shadowed = [p for p in overlays if torch_file.startswith(p + os.sep)]; assert not shadowed, "torch is shadowed by an overlay: " + torch_file; import aurora; import cdsapi; import huggingface_hub; print("IMPORT_CHECK=PASS"); print("torch:", torch.__version__); print("torch file:", torch_file); print("hip:", torch.version.hip); print("aurora:", aurora.__file__)'
}

print_next_steps() {
  log "Next steps"
  cat <<EOF
Use this PYTHONPATH in Aurora Slurm jobs:
  export PYTHONPATH=${AURORA_PY38}:${CAMS_TOOLS}:\${PYTHONPATH:-}

Use this Hugging Face cache:
  export HF_HUB_CACHE=${HF_CACHE}

For CAMS downloads, keep credentials outside git:
  export ADS_API_KEY='...'

Then use the workflow repository for the actual science scripts:
  https://github.com/jingjing-2020/aurora-hygon-dcu

Before a full CAMS forecast, run the memory-check Slurm job and require MEMORY_CHECK=PASS.
EOF
}

main() {
  log "Aurora Hygon DCU server bootstrap"
  load_modules

  if [[ "$ONLY_CHECKS" != "1" ]]; then
    ensure_dirs
  fi

  check_python
  install_aurora
  install_download_tools
  run_import_checks
  print_next_steps

  if [[ -z "${ADS_API_KEY:-}" ]]; then
    warn "ADS_API_KEY is not set. That is fine for install checks, but CAMS downloads need it later."
  fi
}

main "$@"
