#!/usr/bin/env bash
set -euo pipefail

workspace_dir="${WORKSPACE_DIR:-/workspace}"

mkdir -p "${workspace_dir}"
cd "${workspace_dir}"

exec "$@"
