"""Reproducible local/CI check entry; default requires no network or oracle."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--oracle',action='store_true')
parser.add_argument('--corpus',action='store_true')
parser.add_argument('--benchmarks',action='store_true')
args=parser.parse_args()
def run(*cmd):
    print('+ '+' '.join(map(str,cmd)),flush=True)
    subprocess.run(cmd,cwd=root,check=True)
version=subprocess.check_output(['moon','version','--all'],text=True)
pin=json.loads((root/'tools/toolchain.json').read_text())
assert pin['moon'] in version and pin['moon_commit'] in version and pin['moonc'] in version,version
for command in [('moon','fmt','--check'),('moon','check','--target','native','--deny-warn'),('moon','test','--target','native','--deny-warn'),('moon','build','--target','native','--deny-warn')]:run(*command)
(root/'.cache').mkdir(exist_ok=True)
(root/'.cache/writer-example.xpt').unlink(missing_ok=True)
run(str(root/'_build/native/debug/build/examples/write/write.exe'),str(root/'.cache/writer-example.xpt'))
for script in ['test_inspect.py','test_export.py','test_exchange.py','test_fixtures.py','test_malformed.py']:run(sys.executable,str(root/'tools'/script))
run(sys.executable,str(root/'tools/test_consumer.py'))
if args.oracle or args.corpus:run(sys.executable,str(root/'tools/check_writer.py'))
if args.corpus:
    run(sys.executable,str(root/'tools/compare_scan.py'))
    run(sys.executable,str(root/'tools/validate_corpus.py'))
if args.benchmarks:
    run('moon','build','--target','native','--release','--deny-warn')
    run(sys.executable,str(root/'tools/benchmark.py'))
print('PASS: all requested checks completed; none skipped',flush=True)
