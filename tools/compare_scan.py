"""Complete numeric NHANES comparison for the public API scan example."""
import math
import subprocess
from pathlib import Path
import pyreadstat

ROOT=Path(__file__).resolve().parents[1]
exe=ROOT/'_build/native/debug/build/examples/scan/scan.exe'
if not exe.exists():
    matches=list((ROOT/'_build/native').rglob('scan.exe'))
    if len(matches)!=1: raise RuntimeError('build examples/scan first')
    exe=matches[0]
for path in sorted((ROOT/'.cache/corpus').glob('*.xpt')):
    expected,meta=pyreadstat.read_xport(path,disable_datetime_conversion=True)
    output=subprocess.check_output([exe,path,'--values'],text=True).splitlines()
    assert len(output)==len(expected)+1, (path,len(output),len(expected))
    cells=0
    max_ulp=0
    for line,row in zip(output[:-1],expected.itertuples(index=False,name=None),strict=True):
        actual=line.split(',')
        assert len(actual)==len(row)
        for got,want in zip(actual,row,strict=True):
            cells+=1
            if math.isnan(want): assert got=='.', (cells,got,want)
            else:
                value=float(got)
                # ReadStat truncates up to 3 low fraction bits when making IEEE;
                # MoonXPT follows that rule; bound general semantic comparisons by 1 ULP.
                delta=abs(value-want)/math.ulp(want)
                assert delta<=1, (path,cells,value,want,delta)
                if want.is_integer(): assert value==want
                max_ulp=max(max_ulp,delta)
    print(f'{path.stem}: rows={len(expected)} columns={len(expected.columns)} compared_cells={cells} max_ulp={max_ulp:g}; PASS')
