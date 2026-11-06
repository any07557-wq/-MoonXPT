"""Install fresh SDK/oracles and validate the frozen baseline in bubblewrap.

Shares the host kernel and base OS tools; hides the entire developer home,
checks no MoonBit/oracles are present, and downloads all SDK/Python inputs anew.
This is an isolated userspace test, not a claim of using a second physical host.
"""
from datetime import datetime,timezone
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import shutil
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[1]
BASE='1516dfd033d4ecee1bf0fd5cb35c9ec77762a774'
parent=ROOT/'.cache/independent-install';parent.mkdir(parents=True,exist_ok=True)
run=Path(tempfile.mkdtemp(prefix='run-',dir=parent)).resolve()
source=run/'source';source.mkdir()
install_tools=run/'installer-tools';install_tools.mkdir()
for name in ['install_toolchain.py','install_toolchain.sh','toolchain.json']:
    shutil.copyfile(ROOT/'tools'/name,install_tools/name)
runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
archive=subprocess.check_output(['git','archive',BASE],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(source,filter='data')
assert not (source/'.cache').exists() and not (source/'_build').exists()
script=run/'verify.sh'
script.write_text('''#!/usr/bin/env bash
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
Path('/run/oracle-packages.json').write_text(json.dumps(packages,indent=2)+'\\n')
print('Fresh oracle dependencies installed from PyPI',flush=True)
PY
python3 tools/fetch_corpus.py
.cache/venv/bin/python tools/check.py --oracle --corpus
''')
command=['bwrap','--unshare-user','--unshare-pid','--clearenv',
 '--ro-bind','/usr','/usr','--ro-bind','/lib','/lib','--ro-bind','/lib64','/lib64',
 '--ro-bind','/bin','/bin','--ro-bind','/etc','/etc','--proc','/proc','--dev','/dev',
 '--dir','/mnt/wsl','--ro-bind',str(Path('/etc/resolv.conf').resolve()),'/mnt/wsl/resolv.conf',
 '--tmpfs','/home','--dir','/home/user','--tmpfs','/tmp',
 '--bind',str(run),'/run','--ro-bind',str(install_tools),'/release-tools',
 '--setenv','PATH','/usr/bin:/bin','--setenv','LANG','C.UTF-8',
 '--setenv','PYTHONNOUSERSITE','1','--setenv','PIP_CONFIG_FILE','/dev/null',
]
# Forward only the existing transport proxy settings, never credentials or the
# developer environment as a whole. Values are not written into receipts/logs.
for key in ['HTTPS_PROXY','HTTP_PROXY','https_proxy','http_proxy','NO_PROXY','no_proxy']:
    if key in os.environ:command+=['--setenv',key,os.environ[key]]
command+=['--chdir','/run/source','/bin/bash','--noprofile','--norc','/run/verify.sh']
started=datetime.now(timezone.utc).isoformat()
print('Independent run directory:',run,flush=True)
(parent/'latest-run.json').write_text(json.dumps({'directory':str(run.relative_to(ROOT))})+'\n')
with (run/'execution.log').open('w') as log:
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
    assert process.stdout is not None
    for line in process.stdout:
        log.write(line);log.flush();print(line,end='',flush=True)
    code=process.wait()
report={'baseline':BASE,'result':'PASS' if code==0 else 'FAIL','exit_code':code,
 'started_utc':started,'completed_utc':datetime.now(timezone.utc).isoformat(),
 'environment':'bubblewrap isolated userspace; shared host Linux kernel and base /usr /etc',
 'developer_home_visible':False,'existing_sdk_reused':False,'oracle_environment_reused':False,
 'base_os_dns_and_proxy_forwarded':True,
 'sdk_download_cache_reused':False,'pip_cache_reused':False,'source_build_cache_reused':False,
 'corpus_downloaded_afresh':code==0,'ci_run_claimed':False,
 'execution_log_sha256':hashlib.sha256((run/'execution.log').read_bytes()).hexdigest(),
 'installer_source_sha256':hashlib.sha256((install_tools/'install_toolchain.py').read_bytes()).hexdigest(),
 'toolchain_lock_sha256':hashlib.sha256((install_tools/'toolchain.json').read_bytes()).hexdigest(),
 'verification_runner_sha256':runner_hash}
(run/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
raise SystemExit(code)
