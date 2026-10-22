#!/bin/bash
# 构建并立即启动 CutBoardar
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

bash "$ROOT/build.sh"
open "$ROOT/dist/CutBoardar.app"
