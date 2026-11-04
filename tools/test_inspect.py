"""CLI contract checks; works offline with the generated writer fixture."""
import json
import subprocess
from pathlib import Path
import tempfile

exe=Path('_build/native/debug/build/cmd/moonxpt/moonxpt.exe').resolve()
def run(args,code=0):
    p=subprocess.run([exe,*map(str,args)],text=True,capture_output=True)
    assert p.returncode==code,(args,p.returncode,p.stderr)
    if code:
        assert p.stdout=='',p.stdout
        assert json.loads(p.stderr)['kind']
    return p

assert 'SAS XPORT V5' in run(['--help']).stdout
run(['inspect'],2)
run(['inspect','nonexistent-file.xpt'],3)
with tempfile.TemporaryDirectory(prefix='moonxpt path ') as d:
    path=Path(d)/'test file.xpt'
    path.write_bytes(Path('.cache/writer-example.xpt').read_bytes())
    args=['inspect',path,'--json','--rows','NUMBERS=3','--rows','WORDS=3','--rows','TAGS=28','--rows','EMPTY=0']
    result=json.loads(run(args).stdout)
    assert len(result['members'])==4
    assert all(m['row_count'] is None for m in result['members'])
    result=json.loads(run(args+['--count-rows']).stdout)
    assert [m['row_count'] for m in result['members']]==[3,3,28,0]
    assert result['members'][1]['metadata']['name']=='WORDS'
    run(['inspect',path,'--unknown'],2)
    run(['inspect',path,'--max-input-bytes','80'],2)
    bad=Path(d)/'truncated.xpt';bad.write_bytes(path.read_bytes()[:79])
    assert json.loads(run(['inspect',bad,'--json'],2).stderr)['offset']==79
print('PASS: inspect JSON, counts, multi-member hints, spaces in paths, stderr, usage/I/O/format codes')
