"""Regenerate small independently produced inputs (development dependencies)."""
import hashlib
import json
from datetime import datetime
from pathlib import Path
import pandas as pd
import pyreadstat
from xport_compat import xport

root=Path('tests/fixtures');root.mkdir(parents=True,exist_ok=True)
stamp=b'01JAN00:00:00:00'
single=root/'readstat-v5.xpt'
frame=pd.DataFrame({'VALUE':[0.,1.,-1.25,float('nan')],'TEXT':pd.Series(['.A','a,b','a"b','last  '],dtype=object)})
pyreadstat.write_xport(frame,single,file_format_version=5,table_name='ORACLE',file_label='ReadStat independent input',column_labels=['Raw SAS date value','Literal text'],variable_format={'VALUE':'DATE9.'},variable_informat={'VALUE':'BEST12.'})
raw=bytearray(single.read_bytes())
for offset in [144,160,464,480]:raw[offset:offset+16]=stamp
single.write_bytes(raw)
with xport.v56._encoding(data='cp1252',metadata='cp1252'):
    a=xport.Dataset({'ID':pd.Series([1.,2.,3.],dtype='float64'),'TEXT':pd.Series(['a,b','é€',' .A '],dtype=object)},name='FIRST',label='Café €')
    a.created=a.modified=datetime(2000,1,1)
    a['TEXT'].width=12;a['TEXT'].label='Character bytes'
    b=xport.Dataset({'OTHER':pd.Series([-3.5,0.125],dtype='float64')},name='SECOND',label='Different schema')
    b.created=b.modified=datetime(2000,1,1)
    lib=xport.Library([a,b],created=datetime(2000,1,1),modified=datetime(2000,1,1),sas_os='LINUX',sas_version='6.06')
    (root/'xport-multi.xpt').write_bytes(xport.v56.dumps(lib))
# Independent schema vectors derived from the ReadStat fixture.
count=int(raw[614:618]);assert count==2
obs=640+((count*140+79)//80)*80+80
variant=bytearray(raw[:640])
variant[314:318]=b'0136'
for i in range(count):variant+=raw[640+i*140:640+i*140+136]
variant+=b' '*((-count*136)%80)
variant+=raw[obs-80:]
(root/'namestr-136.xpt').write_bytes(variant)
reorder=bytearray(raw)
string_width=int.from_bytes(raw[640+140+4:640+140+6])
reorder[640+84:640+88]=string_width.to_bytes(4,'big')
reorder[780+84:780+88]=(0).to_bytes(4,'big')
width=8+string_width
for i in range(4):
    row=raw[obs+i*width:obs+(i+1)*width]
    reorder[obs+i*width:obs+(i+1)*width]=row[8:]+row[:8]
(root/'reordered-offsets.xpt').write_bytes(reorder)
manifest=[]
for name,producer,purpose in [
    ('readstat-v5.xpt','pyreadstat 1.3.7 / bundled ReadStat; timestamps normalized only','single member, labels, format/informat, missing and literal CSV punctuation'),
    ('xport-multi.xpt','Python xport 3.6.1; pandas constructor adapter only','two different schemas, Windows-1252 metadata and characters'),
    ('namestr-136.xpt','SAS layout vector derived from ReadStat fixture','136-byte descriptors'),
    ('reordered-offsets.xpt','SAS layout vector derived from ReadStat fixture','descriptor order differs from observation positions'),
]:
    p=root/name;data=p.read_bytes()
    manifest.append(dict(file=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),producer=producer,purpose=purpose,license='MIT test data authored for MoonXPT; no external survey records',generated='2026-11-04'))
(root/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(manifest,indent=2))
