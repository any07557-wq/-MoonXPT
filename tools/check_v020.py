"""v0.2.0 validation entry: offline, fixture interoperability or public corpus."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import traceback

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['offline', 'interop', 'corpus'], required=True)
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'mode': args.mode, 'steps': [], 'sas': 'blocked',
              'source_parent_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'source_scope': 'current working-tree files; code hashes recorded, not assumed identical to HEAD',
              'sdk_scope': 'existing fixed SDK; optional CI fresh-install receipt retained separately', 'python': sys.version}
    report['source_files'] = [{'file': str(p.relative_to(ROOT)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                              for p in sorted(ROOT.rglob('*')) if p.is_file() and
                              (p.suffix in {'.mbt', '.c', '.py', '.pkg', '.yml', '.yaml'} or p.name in {'moon.mod','requirements-oracle.txt','toolchain.json','oracles-v0.2.0.json'}) and
                              '.cache' not in p.parts and '_build' not in p.parts and 'dist' not in p.parts and '.git' not in p.parts and
                              (p.parent == ROOT or p.relative_to(ROOT).parts[0] in {'cmd','exchange','platform','examples','tests','tools','.github'})]
    sdk_receipt = os.environ.get('MOONXPT_SDK_RECEIPT')
    if sdk_receipt and Path(sdk_receipt).is_file():
        shutil.copyfile(sdk_receipt, evidence / 'sdk-install.json')
    def run(name, command):
        log = evidence / (name + '.log')
        with log.open('w') as stream:
            process = subprocess.run(list(map(str, command)), cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        report['steps'].append({'name': name, 'command': list(map(str, command)), 'exit_code': process.returncode,
                                'status': 'passed' if process.returncode == 0 else 'failed', 'log': log.name})
        process.check_returncode()
    try:
        version = subprocess.check_output(['moon', 'version', '--all'], text=True)
        lock = json.loads((ROOT / 'tools/toolchain.json').read_text())
        assert all(lock[k] in version for k in ['moon', 'moon_commit', 'moonc'])
        report['toolchain'] = version
        run('protected-baseline', [sys.executable, ROOT / 'tools/verify_v010_baseline.py', '--output', evidence / 'protected-baseline.json'])
        if args.mode == 'offline':
            run('legacy-and-unit', [sys.executable, ROOT / 'tools/check.py'])
            run('layout-fixtures', [sys.executable, ROOT / 'tests/boundary/generators/generate.py', '--check', ROOT / 'tests/boundary/fixtures'])
            run('api-cli', [sys.executable, ROOT / 'tools/test_boundary_cli.py', '--output', evidence / 'api-cli.json'])
            run('resources', [sys.executable, ROOT / 'tools/test_boundary_resources.py', '--evidence-dir', evidence / 'resources'])
        elif args.mode == 'interop':
            run('build', ['moon', 'build', '--target', 'native', '--deny-warn'])
            run('fixture-interop', [sys.executable, ROOT / 'tools/test_interop_v020.py', '--evidence-dir', evidence / 'interop'])
        else:
            run('public-corpus', [sys.executable, ROOT / 'tools/check.py', '--oracle', '--corpus'])
            shutil.copy2(ROOT / '.cache/corpus-results.json', evidence / 'corpus-results.json')
        report['status'] = 'passed'
    except BaseException:
        report['failure'] = traceback.format_exc()
        raise
    finally:
        (evidence / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
        files = [{'file': str(p.relative_to(evidence)), 'bytes': p.stat().st_size,
                  'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(evidence.rglob('*')) if p.is_file()]
        (evidence / 'manifest.json').write_text(json.dumps({'files': files}, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'mode': args.mode, 'evidence': str(evidence)}, indent=2))


if __name__ == '__main__':
    main()
