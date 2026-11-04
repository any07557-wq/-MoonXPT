"""Independent multi-member writer verification. No product code imported."""
from pathlib import Path
import pyreadstat
from xport_compat import xport

path=Path('.cache/writer-example.xpt')
data=path.read_bytes()
lib=xport.v56.loads(data)
assert list(lib)==['NUMBERS','WORDS','TAGS','EMPTY'],list(lib)
assert lib['NUMBERS'].shape==(3,2)
assert list(lib['NUMBERS']['ID'])==[1,2,3]
assert list(lib['NUMBERS']['VALUE'])==[1.25,2.5,3.75]
assert list(lib['WORDS']['TEXT'])==['hello','.A','a,b"c']
assert lib['TAGS'].shape==(28,1)
assert lib['EMPTY'].shape==(0,1)
# ReadStat consumes later members as observations; isolate first member.
single=path.with_name('writer-single.xpt')
single.write_bytes(data[:1120])
df,meta=pyreadstat.read_xport(single,disable_datetime_conversion=True)
assert df.shape==(3,2)
assert meta.column_labels==['Identifier','Measured value']
# xport DataFrame normalizes NaN payloads; verify tags with independent vectors.
pos=240
for name in ['NUMBERS','WORDS','TAGS','EMPTY']:
    assert data[pos+168:pos+176].rstrip()==name.encode()
    count=int(data[pos+320+54:pos+320+58])
    stride=int(data[pos+74:pos+78])
    start=pos+400+((count*stride+79)//80)*80+80
    rows={'NUMBERS':3,'WORDS':3,'TAGS':28,'EMPTY':0}[name]
    width={'NUMBERS':16,'WORDS':16,'TAGS':8,'EMPTY':8}[name]
    if name=='TAGS':
        actual=[data[start+i*8:start+(i+1)*8] for i in range(rows)]
        expected=[bytes([tag])+b'\0'*7 for tag in sorted(b'._ABCDEFGHIJKLMNOPQRSTUVWXYZ')]
        assert actual==expected,(actual,expected)
        import math
        for raw in actual:
            value=xport.v56.ibm_to_ieee(raw)
            if raw[0]==ord('.'):
                assert math.isnan(value)
            else:
                assert value.name==chr(raw[0]) and bytes(value)==raw
    pos=start+((rows*width+79)//80)*80
assert pos==len(data)
print('PASS: xport reads all 4 members; ReadStat reads first; 28 missing byte vectors exact')
