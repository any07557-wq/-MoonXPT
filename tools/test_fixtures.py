"""Offline independent-input and normative-layout regression checks."""
import csv
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

exe=Path('_build/native/debug/build/cmd/moonxpt/moonxpt.exe').resolve()
fixtures=Path('tests/fixtures')
def run(*args):
    p=subprocess.run([exe,*map(str,args)],text=True,capture_output=True)
    assert p.returncode==0,(args,p.returncode,p.stderr)
    return json.loads(p.stdout)
for item in json.loads((fixtures/'manifest.json').read_text()):
    data=(fixtures/item['file']).read_bytes()
    assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
with tempfile.TemporaryDirectory(prefix='moonxpt independent ') as td:
    td=Path(td)
    baseline=None
    for name in ['readstat-v5.xpt','namestr-136.xpt','reordered-offsets.xpt']:
        src=fixtures/name
        info=run('inspect',src,'--json','--count-rows','--rows','ORACLE=4')
        ds=info['members'][0]['metadata']
        assert info['members'][0]['row_count']==4
        assert ds['variables'][0]['format']=={'name':'DATE','width':9,'decimals':0,'justification':1}
        assert ds['variables'][0]['informat']['name']=='BEST'
        c=td/f'{name}.csv';m=td/f'{name}.json'
        run('export',src,'--member','ORACLE','--rows','ORACLE=4','--csv',c,'--metadata',m)
        with c.open(newline='') as f: rows=list(csv.reader(f))
        assert [r[0] for r in rows[1:]]==['0','1','-1.25','.']
        width=ds['variables'][1]['width']
        assert [r[1] for r in rows[1:]]==[s.ljust(width) for s in ['.A','a,b','a"b','last  ']]
        if baseline is None:baseline=rows
        else:assert rows==baseline
        out=td/f'{name}.restored.xpt'
        run('write',c,'--metadata',m,'--output',out)
        restored=run('inspect',out,'--rows','ORACLE=4','--json')
        assert restored['members'][0]['metadata']['descriptor_size']==140
        expected_raw=src.read_bytes()
        # All these fixtures have the same padded descriptor area; compare all
        # physical field bytes to independently generated input, even reordered.
        width=ds['row_width']
        assert out.read_bytes()[1040:1040+4*width]==expected_raw[1040:1040+4*width]
    src=fixtures/'xport-multi.xpt'
    info=run('inspect',src,'--json','--count-rows','--encoding','windows-1252','--tail-policy','trim')
    assert [m['metadata']['name'] for m in info['members']]==['FIRST','SECOND']
    assert [m['row_count'] for m in info['members']]==[3,2]
    assert info['members'][0]['metadata']['label']=='Café €'
    c=td/'cp1252.csv';m=td/'cp1252.json';out=td/'cp1252.xpt'
    run('export',src,'--member','FIRST','--tail-policy','trim','--encoding','windows-1252','--csv',c,'--metadata',m)
    with c.open(newline='') as f:rows=list(csv.reader(f))
    assert rows[2][1].rstrip(' ')=='é€'
    run('write',c,'--metadata',m,'--output',out)
    assert run('inspect',out,'--rows','FIRST=3','--encoding','windows-1252','--json')['members'][0]['metadata']['label']=='Café €'
print('PASS: independent ReadStat/xport inputs, format/informat, 136-byte descriptors, reordered offsets, CP1252 multi-member exchange')
