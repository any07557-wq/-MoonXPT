"""Fetch only fixed corpus entries; no HTML, silent skipping or hash updates."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import urllib.request

root=Path(__file__).resolve().parents[1]
cache=root/'.cache'
cache.mkdir(exist_ok=True)
for item in json.loads((root/'tests/corpus.json').read_text()):
    target=cache/item['name']
    if not target.resolve().is_relative_to(cache.resolve()):raise ValueError('invalid corpus path')
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists():
        assert hashlib.sha256(target.read_bytes()).hexdigest()==item['sha256'],f'bad cached corpus: {target}; remove it and retry'
        print(f'verified cached {item["member"]}',flush=True);continue
    temporary=None
    try:
        digest=hashlib.sha256();size=0
        with tempfile.NamedTemporaryFile(dir=target.parent,prefix='.download-',delete=False) as out:
            temporary=Path(out.name)
            with urllib.request.urlopen(item['url'],timeout=60) as response:
                while chunk:=response.read(65536):
                    size+=len(chunk)
                    if size>50*1024*1024:raise ValueError('corpus download exceeds limit')
                    digest.update(chunk);out.write(chunk)
        assert size==item['bytes'] and size%80==0,(item['member'],size)
        with temporary.open('rb') as f:assert f.read(28)==b'HEADER RECORD*******LIBRARY '
        assert digest.hexdigest()==item['sha256'],f'hash mismatch: {item["member"]}'
        os.replace(temporary,target);temporary=None
        print(f'downloaded and verified {item["member"]}',flush=True)
    finally:
        if temporary is not None:temporary.unlink(missing_ok=True)
