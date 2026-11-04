"""Fixed-seed malformed-input and resource-bound regression driver."""
import json
from pathlib import Path
import random
import subprocess
import tempfile

exe=Path('_build/native/debug/build/cmd/moonxpt/moonxpt.exe').resolve()
data=(Path('tests/fixtures')/'readstat-v5.xpt').read_bytes()
seed=20261104
r=random.Random(seed)
counts={'truncations':0,'mutations':0,'targeted':0}
def call(args,codes):
    p=subprocess.run([exe,*map(str,args)],capture_output=True,text=True,timeout=5)
    assert p.returncode in codes,(args,p.returncode,p.stdout,p.stderr)
    if p.returncode:
        assert p.stdout==''
        d=json.loads(p.stderr);assert d['kind']!='internal'
        return d
    json.loads(p.stdout)
    return None
with tempfile.TemporaryDirectory(prefix='moonxpt malformed ') as td:
    td=Path(td);path=td/'input.xpt'
    path.write_bytes(data)
    call(['inspect',path,'--json','--rows','ORACLE=4','--max-input-bytes',str(len(data))],{0})
    call(['inspect',path,'--json','--rows','ORACLE=4','--max-input-bytes',str(len(data)-1)],{2})
    for length in sorted(set(range(0,len(data),17))|{79,80,159,160,239,240,319,320,639,640,1039,1040,1119}):
        path.write_bytes(data[:length]);call(['inspect',path,'--json','--rows','ORACLE=4'],{2});counts['truncations']+=1
    targets=[(20,b'LIBV8   '),(48,b'1'),(240+74,b'9999'),(614,b'9999'),(640,b'\0\0'),(644,b'\0\1'),(724,b'\xff'*4),(864,b'\0'*4)]
    for at,replacement in targets:
        b=bytearray(data);b[at:at+len(replacement)]=replacement;path.write_bytes(b)
        d=call(['inspect',path,'--json','--rows','ORACLE=4'],{2})
        assert d['offset'] is not None,(at,d)
        counts['targeted']+=1
    # Invalid numerical zero exponent must fail when values are decoded.
    b=bytearray(data);b[1040:1048]=b'\x01'+b'\0'*7;path.write_bytes(b)
    err=call(['export',path,'--rows','ORACLE=4','--member','ORACLE','--csv',td/'bad.csv','--metadata',td/'bad.json'],{2})
    assert err['kind']=='numeric' and err['offset']==1040 and err['row']==0 and err['variable']=='VALUE',err
    assert not (td/'bad.csv').exists() and not (td/'bad.json').exists()
    for _ in range(256):
        b=bytearray(data)
        for _ in range(r.randint(1,4)):b[r.randrange(len(b))]=r.randrange(256)
        path.write_bytes(b);call(['inspect',path,'--json','--rows','ORACLE=4'],{0,2});counts['mutations']+=1
    assert not list(td.glob('*.moonxpt-*'))
result={'seed':seed,**counts,'result':'PASS','timeout_seconds':5}
Path('.cache').mkdir(exist_ok=True)
Path('.cache/malformed-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
