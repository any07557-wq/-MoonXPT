"""Build/test a clean Git archive using the verified installed toolchain.

No build files or virtualenv are copied. --corpus copies only hash-verified real
inputs and uses this process's pinned oracle interpreter, not product runtime.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

project=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--corpus',action='store_true');args=parser.parse_args()
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=project,text=True).strip()
archive=subprocess.check_output(['git','archive','HEAD'],cwd=project)
started=time.monotonic()
with tempfile.TemporaryDirectory(prefix='moonxpt-clean-') as name:
    root=Path(name)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:tar.extractall(root,filter='data')
    assert not (root/'_build').exists() and not (root/'.cache').exists()
    if args.corpus:
        for item in json.loads((root/'tests/corpus.json').read_text()):
            src=project/'.cache'/item['name']
            assert hashlib.sha256(src.read_bytes()).hexdigest()==item['sha256']
            dst=root/'.cache'/item['name'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    log=project/'.cache/clean-reproduction.log';log.parent.mkdir(exist_ok=True)
    command=[sys.executable,str(root/'tools/check.py')]
    if args.corpus:command+=['--oracle','--corpus']
    print('Clean archive:',head,'corpus:',args.corpus,flush=True)
    with log.open('w') as stream:
        subprocess.run(command,cwd=root,stdout=stream,stderr=subprocess.STDOUT,check=True)
    print(log.read_text(),flush=True)
report={'head':head,'result':'PASS','scope':'format, static, 27 MoonBit test groups, native build, CLI, malformed inputs, independent consumer'+(', both oracle families and 3 real full workflows' if args.corpus else ''),'toolchain':'verified installed 0.1.20261012 / v0.10.15+943464bfa','build_cache_copied':False,'oracle_environment_copied':False,'corpus_inputs_copied_and_hash_verified':args.corpus,'network_install_verified':False,'elapsed_seconds':round(time.monotonic()-started,3)}
(project/'.cache/clean-reproduction.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
