"""Read-only protection check for the original release, reports and tests."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = 'bad7ec0158c5585b3a2ba1b0fe99528cfa1ffd7a'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def verify():
    original = git('show', 'c65e673:docs/evidence/v0.2.0/c01/protected-baseline.json')
    assert original == (ROOT / 'docs/evidence/v0.2.0/c01/protected-baseline.json').read_bytes()
    records = json.loads(original)['files']
    for record in records:
        assert hashlib.sha256((ROOT / record['file']).read_bytes()).hexdigest() == record['sha256'], record['file']
    reports = ['docs/validation-report.md', 'docs/benchmarks.md', 'docs/benchmark-results.json',
               'docs/clean-reproduction.json', 'docs/malformed-results.json']
    for name in reports:
        assert (ROOT / name).read_bytes() == git('show', BASE + ':' + name), name
    for name in ['docs/compatibility.md', 'docs/references.md', 'docs/progress.md']:
        assert (ROOT / name).read_bytes().startswith(git('show', BASE + ':' + name)), name
    assert git('rev-parse', 'v0.1.0').decode().strip() == '51ab97700bdaf15e225f432ec1bf27c94dc70a8f'
    assert git('rev-parse', 'v0.1.0^{}').decode().strip() == '2cddd31bb8b88648f619969dbb4fe195051735b4'
    subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], cwd=ROOT, check=True)
    return {'status': 'passed', 'immutable_files': len(records) + len(reports),
            'append_only_documents': 3, 'v010_tag_preserved': True, 'history_preserved': True,
            'boundary': 'Local Git objects and current file bytes verified; no remote mutation or new CI run.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    text = json.dumps(verify(), indent=2) + '\n'
    if args.output:
        args.output.write_text(text)
    print(text, end='')
