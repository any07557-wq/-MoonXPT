#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .cache/venv
.cache/venv/bin/python -m pip install -r tools/requirements-oracle.txt
# xport 3.6.1 declares old pandas; our constructor-only adapter is documented.
# Installing it in a separate no-deps step is intentional, not a runtime dep.
.cache/venv/bin/python -m pip install --no-deps xport==3.6.1
