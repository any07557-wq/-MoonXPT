#!/usr/bin/env bash
set -euo pipefail
cd /run/source
test ! -e /home/user/.moon
test ! -e /home/user/MoonBit_Program
if command -v moon; then echo 'unexpected existing MoonBit' >&2; exit 1; fi
python3 -I - <<'PY'
import importlib.util,json,sys
names=['pyreadstat','xport','pandas','numpy']
presence={name:importlib.util.find_spec(name) is not None for name in names}
assert not any(presence.values()),presence
print('PRECHECK: developer home hidden, no existing SDK or oracle modules',flush=True)
PY
bash /release-tools/install_toolchain.sh /run/sdk --receipt /run/sdk-install.json
export MOON_HOME=/run/sdk
export PATH=/run/sdk/bin:/usr/bin:/bin
python3 -m venv .cache/venv
.cache/venv/bin/python -m pip --isolated install --no-cache-dir --index-url https://pypi.org/simple -r tools/requirements-oracle.txt
.cache/venv/bin/python -m pip --isolated install --no-cache-dir --index-url https://pypi.org/simple --no-deps xport==3.6.1
.cache/venv/bin/python - <<'PY'
from importlib.metadata import distributions
import json
from pathlib import Path
packages={d.metadata['Name']:d.version for d in distributions()}
Path('/run/oracle-packages.json').write_text(json.dumps(packages,indent=2)+'\n')
print('Fresh oracle dependencies installed from PyPI',flush=True)
PY
python3 tools/fetch_corpus.py
.cache/venv/bin/python tools/check.py --oracle --corpus
