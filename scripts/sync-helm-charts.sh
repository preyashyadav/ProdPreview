#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="$ROOT_DIR/deploy/helm/services"
APP_CHARTS_DIR="$ROOT_DIR/deploy/helm/app/charts"

mkdir -p "$APP_CHARTS_DIR"

rsync -a --delete "$SERVICES_DIR/api/" "$APP_CHARTS_DIR/api/"
rsync -a --delete "$SERVICES_DIR/frontend/" "$APP_CHARTS_DIR/frontend/"
rsync -a --delete "$SERVICES_DIR/worker/" "$APP_CHARTS_DIR/worker/"

echo "Synced service charts into $APP_CHARTS_DIR"
