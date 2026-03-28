#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$ROOT_DIR/deploy/helm/services"
APP_DIR="$ROOT_DIR/deploy/helm/app"
APP_CHARTS_DIR="$APP_DIR/charts"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_command helm
require_command rsync

echo "Removing existing chart copies from $APP_CHARTS_DIR"
rm -rf "$APP_CHARTS_DIR"

echo "Creating fresh chart directory at $APP_CHARTS_DIR"
mkdir -p "$APP_CHARTS_DIR"

copy_chart() {
  local service_name="$1"
  local source_dir="$SERVICES_DIR/$service_name/"
  local target_dir="$APP_CHARTS_DIR/$service_name/"

  rsync -a "$source_dir" "$target_dir"
  echo "Copied: deploy/helm/services/$service_name -> deploy/helm/app/charts/$service_name"
}

copy_chart api
copy_chart frontend
copy_chart worker

echo
echo "Verifying umbrella chart dependencies"
helm dependency list "$APP_DIR/"
