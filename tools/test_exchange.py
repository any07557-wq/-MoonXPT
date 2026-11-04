"""CSV/metadata rebuilding and failure cleanup, offline product integration."""
import csv
import json
import subprocess
import tempfile
from pathlib import Path

exe=Path('_build/native/debug/build/cmd/moonxpt/moonxpt.exe').resolve()
source=Path('.cache/writer-example.xpt').resolve()
def run(args,code=0):
    p=subprocess.run([exe,*map(str,args)],text=True,capture_output=True)
    assert p.returncode==code,(args,p.returncode,p.stdout,p.stderr)
    if code: assert p.stdout=='' and json.loads(p.stderr)['kind']
    return p
hints=[x for name,n in [('NUMBERS',3),('WORDS',3),('TAGS',28),('EMPTY',0)] for x in ['--rows',f'{name}={n}']]
with tempfile.TemporaryDirectory(prefix='moonxpt roundtrip ') as d:
    root=Path(d)
    for member,count in [('NUMBERS',3),('WORDS',3),('TAGS',28),('EMPTY',0)]:
        c=root/f'{member}.csv';m=root/f'{member}.json';out=root/f'{member}.xpt'
        run(['export',source,'--member',member,'--csv',c,'--metadata',m,*hints])
        run(['write',c,'--metadata',m,'--output',out])
        info=json.loads(run(['inspect',out,'--rows',f'{member}={count}','--count-rows','--json']).stdout)
        assert info['members'][0]['row_count']==count
        c2=root/f'{member}2.csv';m2=root/f'{member}2.json'
        run(['export',out,'--member',member,'--rows',f'{member}={count}','--csv',c2,'--metadata',m2])
        assert c.read_bytes()==c2.read_bytes(),member
        assert json.loads(m.read_text())==json.loads(m2.read_text()),member
        run(['write',c,'--metadata',m,'--output',out],3)
        original=out.read_bytes();run(['write',c,'--metadata',m,'--output',out,'--force'])
        assert out.read_bytes()==original
    c=root/'NUMBERS.csv';m=root/'NUMBERS.json';bad=root/'bad.csv';out=root/'failed.xpt'
    variants=['ID,VALUE\n1,\n2,2.5\n3,3.75\n','ID,VALUE\n"open','ID,VALUE\n1,2,3\n','VALUE,ID\n1,2\n','ID,VALUE\n1,NaN\n2,2.5\n3,3.75\n']
    for data in variants:
        bad.write_text(data);run(['write',bad,'--metadata',m,'--output',out],2)
        assert not out.exists()
    original=json.loads(m.read_text());broken={**original,'schema_version':999};bm=root/'bad.json';bm.write_text(json.dumps(broken))
    run(['write',c,'--metadata',bm,'--output',out],2)
    broken=json.loads(m.read_text());broken['dataset']['variables'][1]['name']='ID';bm.write_text(json.dumps(broken))
    run(['write',c,'--metadata',bm,'--output',out],2)
    run(['write',c,'--metadata',m,'--output',c,'--force'],2)
    assert not list(root.glob('*.moonxpt-*'))
print('PASS: four member CSV/JSON semantic roundtrips, stable writes, typed missing, versions, duplicate columns, malformed CSV and cleanup')
