"""Clean committed Git checkout, no project build/cache reuse, existing pinned SDK."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import traceback

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--commit', default='HEAD')
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    head = subprocess.check_output(['git', 'rev-parse', args.commit + '^{commit}'], cwd=ROOT, text=True).strip()
    report = {'status': 'failed', 'source_commit': head, 'project_build_cache_reused': False,
              'sdk': 'existing pinned SDK, not a new SDK installation', 'oracle': 'not requested; offline core reproduction',
              'boundary': 'new local clone and build directory; shared host OS/kernel and fixed SDK, not a new machine or remote CI'}
    try:
        with tempfile.TemporaryDirectory(prefix='moonxpt-v020-clean-') as temporary:
            clone = Path(temporary) / 'source'
            subprocess.run(['git', 'clone', '--no-hardlinks', '--no-checkout', str(ROOT), str(clone)], check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            subprocess.run(['git', 'checkout', '--detach', head], cwd=clone, check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            assert not (clone / '.cache').exists() and not (clone / '_build').exists()
            with (evidence / 'clean-checkout.log').open('w') as stream:
                process = subprocess.run([sys.executable, clone / 'tools/check_v020.py', '--mode', 'offline',
                                          '--evidence-dir', evidence / 'offline'], cwd=clone,
                                         stdout=stream, stderr=subprocess.STDOUT)
            report['exit_code'] = process.returncode
            process.check_returncode()
            assert subprocess.check_output(['git', 'status', '--porcelain'], cwd=clone, text=True).strip() == ''
        report['status'] = 'passed'
    except BaseException:
        report['failure'] = traceback.format_exc()
        raise
    finally:
        (evidence / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
        files = [{'file': str(p.relative_to(evidence)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                 for p in sorted(evidence.rglob('*')) if p.is_file()]
        (evidence / 'manifest.json').write_text(json.dumps({'files': files}, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
