#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Rojo Inicio.app"
[[ -d "$APP" ]] || "$ROOT/scripts/build.sh"
if [[ -w /Applications ]]; then ditto "$APP" "/Applications/Rojo Inicio.app"; else sudo ditto "$APP" "/Applications/Rojo Inicio.app"; fi
open "/Applications/Rojo Inicio.app"
