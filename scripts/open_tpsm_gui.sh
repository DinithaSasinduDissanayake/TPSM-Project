#!/usr/bin/env bash
set -euo pipefail

URL="http://127.0.0.1:8787"
xdg-open "${URL}" >/dev/null 2>&1 || true
