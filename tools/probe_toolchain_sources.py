"""Read-only official-source probes for release installation investigation.

No downloaded executable is run; archive reads are restricted to a prefix.
Outputs go only to the ignored investigation cache.
"""
from concurrent.futures import ThreadPoolExecutor
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
PARENT=ROOT/'.cache/toolchain-investigation'
OUT=PARENT/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
ITEMS=[
 ('installer','https://cli.moonbitlang.com/install/unix.sh',False),
 ('pinned-native','https://cli.moonbitlang.com/binaries/0.1.20261012%2B748b63c/moonbit-linux-x86_64.tar.gz',True),
 ('pinned-core','https://cli.moonbitlang.com/cores/core-0.1.20261012%2B748b63c.tar.gz',True),
 ('pinned-checksum','https://cli.moonbitlang.com/binaries/0.1.20261012%2B748b63c/moonbit-linux-x86_64.tar.gz.sha256',False),
 ('latest-checksums','https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.sha256',False),
 ('latest-archive-checksum','https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz.sha256',False),
 ('compiler-readme','https://raw.githubusercontent.com/moonbitlang/moonbit-compiler/main/README.md',False),
 ('compiler-tags','https://api.github.com/repos/moonbitlang/moonbit-compiler/tags?per_page=100',False),
 ('moon-releases','https://api.github.com/repos/moonbitlang/moon/releases?per_page=10',False),
 ('compiler-pinned-release','https://api.github.com/repos/moonbitlang/moonbit-compiler/releases/tags/v0.10.15%2B943464bfa',False),
 ('compiler-native-key','https://cli.moonbitlang.com/binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz',True),
 ('compiler-v-native-key','https://cli.moonbitlang.com/binaries/v0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz',True),
 ('official-setup-repo','https://api.github.com/repos/moonbitlang/setup-moonbit',False),
 ('compiler-assets-html','https://github.com/moonbitlang/moonbit-compiler/releases/expanded_assets/v0.10.15%2B943464bfa',False),
 ('compiler-pinned-page','https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.15%2B943464bfa',False),
 ('compiler-key-checksum','https://cli.moonbitlang.com/binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz.sha256',False),
 ('compiler-v-key-checksum','https://cli.moonbitlang.com/binaries/v0.10.15%2B943464bfa/moonbit-linux-x86_64.tar.gz.sha256',False),
 ('compiler-pinned-wasm','https://github.com/moonbitlang/moonbit-compiler/releases/download/v0.10.15%2B943464bfa/moonbit-wasm.tar.gz',True),
 ('compiler-key-core','https://cli.moonbitlang.com/cores/core-0.10.15%2B943464bfa.tar.gz',True),
 ('compiler-key-core-checksum','https://cli.moonbitlang.com/cores/core-0.10.15%2B943464bfa.tar.gz.sha256',False),
 ('compiler-key-files-checksum','https://cli.moonbitlang.com/binaries/0.10.15%2B943464bfa/moonbit-linux-x86_64.sha256',False),
]

def fetch(item):
    name,url,prefix=item
    headers={'User-Agent':'MoonXPT-release-investigation/0.1.0'}
    if prefix:headers['Range']='bytes=0-511'
    request=urllib.request.Request(url,headers=headers)
    limit=512 if prefix else 2*1024*1024
    try:
        try:
            response=urllib.request.urlopen(request,timeout=35)
        except urllib.error.HTTPError as error:
            response=error
        with response:
            data=response.read(limit)
            status=response.status
            selected={k:v for k,v in response.headers.items() if k.lower() in {
                'content-type','content-length','content-range','server','via','x-cache','x-amz-error-code','location','date'}}
            result={'name':name,'url':url,'resolved_url':response.geturl(),'http_status':status,'headers':selected,
                'saved_bytes':len(data),'body_sha256':hashlib.sha256(data).hexdigest(),'prefix_only':prefix,
                'body_file':name+'.body','result':'received'}
        (OUT/(name+'.body')).write_bytes(data)
    except Exception as error:
        result={'name':name,'url':url,'result':'request_failed','error':str(error)}
    return result

parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
items=ITEMS if not args.only else [x for x in ITEMS if x[0] in args.only]
if args.only and set(args.only)!={x[0] for x in items}:raise ValueError('unknown probe name')
OUT.mkdir(parents=True,exist_ok=False)
with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(fetch,items))
report={'probed_at_utc':datetime.now(timezone.utc).isoformat(),'requests':results}
(OUT/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
(PARENT/'latest-run.json').write_text(json.dumps({'report':str((OUT/'sources.json').relative_to(ROOT))})+'\n')
print('Report:',OUT/'sources.json',flush=True)
for result in results:print(json.dumps({k:result.get(k) for k in ['name','http_status','saved_bytes','error']}),flush=True)
