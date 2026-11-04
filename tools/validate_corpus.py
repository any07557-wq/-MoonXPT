"""Three complete real workflows against pinned pyreadstat/ReadStat.

Network acquisition is separate. This command fails if any corpus file is missing
or has changed. No Python code is part of the released CLI or library.
"""
import csv
import hashlib
import json
import math
import subprocess
import tempfile
from pathlib import Path
import numpy as np
import pyreadstat

ROOT=Path(__file__).resolve().parents[1]
EXE=ROOT/'_build/native/debug/build/cmd/moonxpt/moonxpt.exe'
def run(*args):
    p=subprocess.run([EXE,*map(str,args)],text=True,capture_output=True)
    if p.returncode: raise RuntimeError((args,p.returncode,p.stderr))
    return json.loads(p.stdout)

def descriptor_metadata(data):
    import struct
    count=int(data[240+320+54:240+320+58])
    stride=int(data[240+74:240+78])
    variables=[]
    def s(b):return b.decode('cp1252').rstrip(' ')
    for i in range(count):
        b=data[640+i*stride:640+(i+1)*stride]
        typ,h,width,num=struct.unpack('>HHHH',b[:8])
        f={'name':s(b[56:64]),'width':int.from_bytes(b[64:66]),'decimals':int.from_bytes(b[66:68]),'justification':int.from_bytes(b[68:70])}
        inf={'name':s(b[72:80]),'width':int.from_bytes(b[80:82]),'decimals':int.from_bytes(b[82:84]),'justification':0}
        variables.append(dict(name=s(b[8:16]),label=s(b[16:56]),type='numeric' if typ==1 else 'character',width=width,position=int.from_bytes(b[84:88]),number=num,hash=h,format=f,informat=inf))
    return variables

results=[]
for item in json.loads((ROOT/'tests/corpus.json').read_text()):
    path=ROOT/'.cache'/item['name']
    data=path.read_bytes()
    assert hashlib.sha256(data).hexdigest()==item['sha256'],path
    df,meta=pyreadstat.read_xport(path,disable_datetime_conversion=True)
    member=item['member'];n=len(df)
    inspect=run('inspect',path,'--json','--count-rows','--rows',f'{member}={n}','--encoding','windows-1252')
    actual=inspect['members'][0]
    assert actual['row_count']==n
    assert actual['metadata']['variables']==descriptor_metadata(data)
    assert [v['label'] for v in actual['metadata']['variables']]==[s or '' for s in meta.column_labels]
    with tempfile.TemporaryDirectory(prefix='moonxpt corpus ') as td:
        td=Path(td);c=td/'table.csv';m=td/'table.json';out=td/'restored.xpt'
        run('export',path,'--member',member,'--csv',c,'--metadata',m,'--encoding','windows-1252','--rows',f'{member}={n}')
        with c.open(newline='') as stream:
            rows=csv.reader(stream);assert next(rows)==list(df.columns)
            count=0
            for row,expected in zip(rows,df.itertuples(index=False,name=None),strict=True):
                assert len(row)==len(expected)
                for x,y in zip(row,expected,strict=True):
                    if math.isnan(y):assert x=='.'
                    else:assert float(x)==y,(path,count,x,y)
                count+=1
            assert count==n
        run('write',c,'--metadata',m,'--output',out)
        rebuilt,rebuilt_meta=pyreadstat.read_xport(out,disable_datetime_conversion=True)
        assert list(rebuilt.columns)==list(df.columns)
        np.testing.assert_array_equal(df.to_numpy(),rebuilt.to_numpy())
        assert meta.column_labels==rebuilt_meta.column_labels
        assert meta.original_variable_types==rebuilt_meta.original_variable_types
        rebuilt_info=run('inspect',out,'--json','--count-rows','--rows',f'{member}={n}','--encoding','windows-1252')
        assert rebuilt_info['members'][0]==actual
    result=dict(member=member,rows=n,columns=len(df.columns),cells=n*len(df.columns),sha256=item['sha256'],max_ulp=0,metadata='exact declared attributes',result='PASS')
    results.append(result);print(json.dumps(result),flush=True)
(ROOT/'.cache/corpus-results.json').write_text(json.dumps(results,indent=2)+'\n')
