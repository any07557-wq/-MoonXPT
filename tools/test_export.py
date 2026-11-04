"""Streaming export and output safety contracts, using independent csv/json."""
import csv
import json
from pathlib import Path
import subprocess
import tempfile

exe=Path('_build/native/debug/build/cmd/moonxpt/moonxpt.exe').resolve()
source=Path('.cache/writer-example.xpt').resolve()
def run(args,code=0):
    p=subprocess.run([exe,*map(str,args)],text=True,capture_output=True)
    assert p.returncode==code,(args,p.returncode,p.stdout,p.stderr)
    if code: assert p.stdout=='' and json.loads(p.stderr)['kind']
    return p
hints=[x for name,n in [('NUMBERS',3),('WORDS',3),('TAGS',28),('EMPTY',0)] for x in ['--rows',f'{name}={n}']]
with tempfile.TemporaryDirectory(prefix='moonxpt export ') as d:
    root=Path(d);out=root/'data file.csv';meta=root/'data file.json'
    args=['export',source,'--member','WORDS','--csv',out,'--metadata',meta,*hints]
    run(args)
    with out.open(newline='') as f: rows=list(csv.reader(f))
    assert rows==[['TEXT'],['hello           '],['.A              '],['a,b"c           ']],rows
    metadata=json.loads(meta.read_text())
    assert metadata['schema_version']==1 and metadata['row_count']==3
    original=(out.read_bytes(),meta.read_bytes())
    run(args,3)
    assert original==(out.read_bytes(),meta.read_bytes())
    run(args+['--force'])
    assert original==(out.read_bytes(),meta.read_bytes())
    run(['export',source,'--member','WORDS','--csv',source,'--metadata',meta,*hints],2)
    run(['export',source,'--member','WORDS','--csv',root/'new.csv','--metadata',root/'new.csv',*hints],2)
    before=set(root.iterdir())
    badargs=['export',source,'--member','ABSENT','--csv',root/'absent.csv','--metadata',root/'absent.json',*hints]
    run(badargs,2)
    assert set(root.iterdir())==before
    assert not list(root.glob('*.moonxpt-*'))
print('PASS: selected member export, independent CSV/JSON, no overwrite, force, aliases, failure cleanup')
