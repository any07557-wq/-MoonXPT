"""Install the exact official compiler release into a new prefix.

No existing MoonBit installation or download cache is read. Compiler archive
hash is published upstream; core hash provenance is stated in toolchain.json.
"""
import argparse
from datetime import datetime,timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import tempfile
import time
import urllib.request

parser=argparse.ArgumentParser()
parser.add_argument('prefix',type=Path)
parser.add_argument('--receipt',type=Path)
args=parser.parse_args()
lock=json.loads(Path(__file__).with_name('toolchain.json').read_text())
prefix=args.prefix.resolve()
if prefix.exists():raise SystemExit('prefix already exists; choose a new directory')
if platform.system()!='Linux' or platform.machine()!='x86_64':raise SystemExit('only Linux x86_64 is validated')
version=lock['archive_version'].replace('+','%2B')
origin='https://cli.moonbitlang.com'
native_url=f'{origin}/binaries/{version}/moonbit-linux-x86_64.tar.gz'
core_url=f'{origin}/cores/core-{version}.tar.gz'

def download(url,path,max_bytes):
    print('Downloading:',url,flush=True)
    digest=hashlib.sha256();size=0;next_progress=16*1024*1024;started=time.monotonic()
    request=urllib.request.Request(url,headers={'User-Agent':'MoonXPT-fixed-installer/0.1.0'})
    with urllib.request.urlopen(request,timeout=60) as response,path.open('wb') as stream:
        if response.status!=200:raise ValueError(f'expected full HTTP 200 response, got {response.status}')
        while chunk:=response.read(1024*1024):
            if time.monotonic()-started>600:raise TimeoutError('download exceeded 600 second wall-clock limit')
            size+=len(chunk)
            if size>max_bytes:raise ValueError('download allocation limit exceeded')
            digest.update(chunk);stream.write(chunk)
            if size>=next_progress:
                print('Downloaded bytes:',size,flush=True);next_progress+=16*1024*1024
    return {'url':url,'bytes':size,'sha256':digest.hexdigest()}

started=datetime.now(timezone.utc).isoformat()
with tempfile.TemporaryDirectory(prefix='moonxpt-sdk-download-') as name:
    scratch=Path(name)
    checksum=scratch/'native.sha256'
    download(native_url+'.sha256',checksum,4096)
    tokens=checksum.read_text().split()
    if tokens!=[lock['archive_sha256'],'moonbit-linux-x86_64.tar.gz']:raise ValueError('official checksum disagrees with fixed lock')
    native=scratch/'moonbit.tar.gz';core=scratch/'core.tar.gz'
    native_info=download(native_url,native,300*1024*1024)
    if native_info['sha256']!=lock['archive_sha256']:raise ValueError('compiler archive SHA-256 mismatch')
    core_info=download(core_url,core,30*1024*1024)
    if core_info['sha256']!=lock['core_sha256']:raise ValueError('core archive SHA-256 mismatch')
    prefix.mkdir(parents=True)
    with tarfile.open(native) as archive:archive.extractall(prefix,filter='data')
    with tarfile.open(core) as archive:archive.extractall(prefix/'lib',filter='data')
    # The upstream installer explicitly restores executable modes after extract.
    for executable in (prefix/'bin').iterdir():
        if executable.is_file():executable.chmod(executable.stat().st_mode|0o111)
    tcc=prefix/'bin/internal/tcc'
    if tcc.exists():tcc.chmod(tcc.stat().st_mode|0o111)
    env=dict(os.environ,MOON_HOME=str(prefix),PATH=str(prefix/'bin')+os.pathsep+os.environ.get('PATH','/usr/bin:/bin'))
    moon=prefix/'bin/moon'
    raw_version=subprocess.check_output([moon,'version','--all'],env=env,text=True)
    if not all(value in raw_version for value in [lock['moon'],lock['moon_commit'],lock['moonc']]):raise ValueError('installed version differs from frozen toolchain')
    print(raw_version,flush=True)
    subprocess.run([moon,'-C',prefix/'lib/core','bundle','--warn-list','-a','--target','native'],env=env,check=True)
    core_module=(prefix/'lib/core/moon.mod').read_text()
    if '0.10.15+943464bfa' not in core_module:raise ValueError('core version does not match frozen compiler')
receipt={'result':'PASS','started_utc':started,'completed_utc':datetime.now(timezone.utc).isoformat(),
    'archive_version':lock['archive_version'],'prefix':str(prefix),'native':native_info,'core':core_info,
    'core_digest_provenance':lock['core_sha256_provenance'],'version_output':raw_version,
    'download_cache_reused':False,'existing_sdk_read':False,'bundled_backend':'native'}
if args.receipt:
    args.receipt.parent.mkdir(parents=True,exist_ok=True)
    args.receipt.write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt),flush=True)
