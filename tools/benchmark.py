"""Bounded-memory synthetic export experiment (Linux /usr/bin/time).

The load repeats one authored fixture observation; it is not survey data.
"""
import json
import platform
import subprocess
import tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[1]
exe=root/'_build/native/release/build/cmd/moonxpt/moonxpt.exe'
fixture=(root/'tests/fixtures/readstat-v5.xpt').read_bytes()
prefix=fixture[:1040];row=fixture[1040:1054]
assert len(row)==14
results=[]
with tempfile.TemporaryDirectory(prefix='moonxpt synthetic ') as td:
    td=Path(td)
    for n in [10000,100000,1000000]:
        src=td/f'{n}.xpt';csv=td/f'{n}.csv';meta=td/f'{n}.json';stats=td/f'{n}.time'
        with src.open('wb') as f:
            f.write(prefix)
            remaining=n
            while remaining:
                count=min(remaining,4096);f.write(row*count);remaining-=count
            f.write(b' '*((-n*14)%80))
        p=subprocess.run(['/usr/bin/time','-f','{"elapsed_seconds":%e,"peak_rss_kib":%M}','-o',stats,exe,'export',src,'--member','ORACLE','--rows',f'ORACLE={n}','--csv',csv,'--metadata',meta],text=True,capture_output=True,timeout=120)
        assert p.returncode==0,p.stderr
        assert json.loads(p.stdout)['row_count']==n
        with csv.open('rb') as f:
            count=sum(chunk.count(b'\n') for chunk in iter(lambda:f.read(65536),b''))
        assert count==n+1
        result={'synthetic_rows':n,'input_bytes':src.stat().st_size,'csv_bytes':csv.stat().st_size,**json.loads(stats.read_text())}
        restored=td/f'{n}.restored.xpt';write_stats=td/f'{n}.write.time'
        p=subprocess.run(['/usr/bin/time','-f','{"write_elapsed_seconds":%e,"write_peak_rss_kib":%M}','-o',write_stats,exe,'write',csv,'--metadata',meta,'--output',restored],text=True,capture_output=True,timeout=120)
        assert p.returncode==0,p.stderr
        assert json.loads(p.stdout)['row_count']==n and restored.stat().st_size==src.stat().st_size
        result.update(json.loads(write_stats.read_text()))
        results.append(result);print(json.dumps(result),flush=True)
assert max(r['peak_rss_kib'] for r in results)-min(r['peak_rss_kib'] for r in results)<8192
assert max(r['write_peak_rss_kib'] for r in results)-min(r['write_peak_rss_kib'] for r in results)<8192
report={'backend':'native release','os':platform.platform(),'toolchain':subprocess.check_output(['moon','version','--all'],text=True).strip(),'method':'/usr/bin/time GNU elapsed + maximum resident set; full CSV export including fsync; authored fixture row repetition','results':results,'result':'PASS: 100x rows; RSS spread under 8 MiB'}
(root/'.cache/benchmark-results.json').write_text(json.dumps(report,indent=2)+'\n')
