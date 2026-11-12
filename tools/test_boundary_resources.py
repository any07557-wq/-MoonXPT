"""Measure actual CLI resource-limit rejection; RSS is observation, not a performance claim."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests/boundary/generators'))
from generate import file_bytes, header


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    results = []
    cli = ROOT / '_build/native/debug/build/cmd/moonxpt/moonxpt.exe'
    for size in [8, 64, 512]:
        for kind in ['valid-headers', 'invalid-markers']:
            data = file_bytes([('A', [81], b'x' * 81)] +
                              [(f'M{i:05}', [], b'') for i in range(size)]) if kind == 'valid-headers' else (
                file_bytes([('A', [80], header('MEMBER') * size)]))
            source = evidence / f'{kind}-{size}.xpt'
            source.write_bytes(data)
            stats = evidence / f'{kind}-{size}.time.json'
            command = [str(cli), 'inspect', str(source), '--json', '--max-boundary-candidates', '4']
            if Path('/usr/bin/time').exists():
                command = ['/usr/bin/time', '-q', '-f', '{"max_rss_kib":%M,"wall_seconds":%e}', '-o', str(stats), *command]
            start = time.perf_counter()
            process = subprocess.run(command, capture_output=True, text=True, timeout=15)
            elapsed = time.perf_counter() - start
            assert process.returncode == 2 and not process.stdout
            diagnostic = json.loads(process.stderr)
            assert diagnostic['code'] == 'E_V5_RESOURCE_LIMIT', diagnostic
            results.append({'input_bytes': len(data), 'input_markers': size, 'candidate_limit': 4,
                            'kind': kind, 'fixture_sha256': hashlib.sha256(data).hexdigest(),
                            'elapsed_seconds': elapsed, 'measurement': json.loads(stats.read_text()) if stats.exists() else None,
                            'diagnostic': diagnostic, 'status': 'passed'})
    report = {'status': 'passed', 'seed': 'deterministic layout; no random inputs', 'cases': results,
              'boundary': 'Debug native CLI, explicit candidate limits. GNU time child RSS where available. No release throughput or universal memory claim.'}
    (evidence / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': 'passed', 'cases': len(results)}, indent=2))


if __name__ == '__main__':
    main()
