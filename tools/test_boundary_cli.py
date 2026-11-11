"""v0.2.0 API-facing CLI acceptance: no oracle, network or golden mutation."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / '_build/native/debug/build/cmd/moonxpt/moonxpt.exe'
FIXTURES = ROOT / 'tests/boundary/fixtures'


def run(*args, code=0):
    process = subprocess.run([EXE, *map(str, args)], capture_output=True, text=True, timeout=15)
    assert process.returncode == code, (args, process.returncode, process.stdout, process.stderr)
    if code:
        assert not process.stdout, process.stdout
        return json.loads(process.stderr)
    return json.loads(process.stdout)


def test():
    result = {}
    def passed(case):
        result[case] = 'passed'
    for entry in json.loads((FIXTURES / 'manifest.json').read_text()):
        assert hashlib.sha256((FIXTURES / entry['file']).read_bytes()).hexdigest() == entry['sha256']
    short = FIXTURES / 'short-ambiguous.xpt'
    wide = FIXTURES / 'wide-unique.xpt'
    header = run('inspect', short, '--json', '--header-only')
    assert header['members'][0]['row_count_status'] == 'not_scanned'
    assert header['members'][0]['boundary_status'] == 'unverified' and not header['scan_complete']
    passed('A01')
    inferred = run('inspect', FIXTURES / 'short-unique.xpt', '--json', '--count-rows')['members'][0]
    assert inferred['row_count'] == 26 and inferred['row_count_status'] == 'inferred'
    passed('A02')
    provided = run('inspect', wide, '--json', '--count-rows', '--rows', 'A=1')['members'][0]
    assert provided['row_count'] == 1 and provided['row_count_status'] == 'provided'
    passed('A03')
    ambiguous = run('inspect', short, '--json', '--count-rows', code=2)
    assert ambiguous['code'] == 'E_V5_ROW_COUNT_AMBIGUOUS'
    assert ambiguous['boundary']['row_count_status'] == 'ambiguous'
    assert 2 in ambiguous['boundary']['candidate_counts']
    passed('A04')
    invalid = run('inspect', FIXTURES / 'invalid-padding.xpt', '--json', code=2)
    assert invalid['boundary']['row_count_status'] == 'invalid'
    assert invalid['boundary']['boundary_status'] == 'invalid'
    passed('A05')
    assert ambiguous['boundary']['boundary_status'] == 'validated'
    passed('A06')
    multi = run('inspect', FIXTURES / 'multi-unique.xpt', '--json', '--count-rows',
                '--rows', 'A=1', '--rows', 'B=1')['members']
    assert [m['row_count'] for m in multi] == [1, 1]
    passed('A07')
    for args in [('--rows', 'A=-1'), ('--rows', 'A=9223372036854775808'),
                 ('--rows', 'A=1', '--rows', 'a=1'), ('--rows', 'UNKNOWN=1'),
                 ('--require-row-count',)]:
        run('inspect', wide, '--json', *args, code=2)
    missing = run('inspect', FIXTURES / 'multi-unique.xpt', '--json', '--rows', 'A=1', '--require-row-count', code=2)
    assert missing['code'] == 'E_V5_ROW_COUNT_REQUIRED'
    passed('A08')
    boundary = provided['boundary']
    assert boundary['hint'] == 1 and boundary['expected_bytes'] == 81 and boundary['actual_bytes'] == 160
    assert boundary['padding_bytes'] == 79 and boundary['alignment_ok']
    assert isinstance(boundary['candidate_counts'][0], int)
    passed('A09')
    assert ambiguous['kind'] == 'ambiguous' and isinstance(ambiguous['reason'], str)
    passed('A10')
    run('inspect', FIXTURES / 'not-present.xpt', '--json', code=3)
    run('inspect', wide, '--not-an-option', code=2)
    passed('A11')
    with tempfile.TemporaryDirectory(prefix='moonxpt v020 cli ') as name:
        folder = Path(name)
        data = folder / 'out.csv'
        meta = folder / 'out.json'
        run('export', short, '--member', 'A', '--rows', 'A=2', '--csv', data, '--metadata', meta)
        original = (data.read_bytes(), meta.read_bytes())
        run('export', short, '--member', 'A', '--rows', 'A=2', '--csv', data, '--metadata', meta, code=3)
        assert (data.read_bytes(), meta.read_bytes()) == original
        run('export', short, '--member', 'A', '--rows', 'A=2', '--csv', meta, '--metadata', meta, code=2)
        passed('A12')
        failed_csv, failed_meta = folder / 'failed.csv', folder / 'failed.json'
        run('export', short, '--member', 'A', '--csv', failed_csv, '--metadata', failed_meta, code=2)
        assert not failed_csv.exists() and not failed_meta.exists()
        assert not list(folder.glob('*.moonxpt-*'))
        run('export', FIXTURES / 'truncated-member-header.xpt', '--member', 'A', '--rows', 'A=1',
            '--csv', failed_csv, '--metadata', failed_meta, code=2)
        assert not failed_csv.exists() and not failed_meta.exists()
        assert not list(folder.glob('*.moonxpt-*'))
        passed('A13')
        out = folder / 'risky.xpt'
        risk = run('write', data, '--metadata', meta, '--output', out, code=2)
        assert risk['code'] == 'E_V5_WRITER_AMBIGUOUS_TAIL'
        assert not out.exists() and not list(folder.glob('*.moonxpt-*'))
        out.write_bytes(b'ORIGINAL')
        run('write', data, '--metadata', meta, '--output', out, '--force', code=2)
        assert out.read_bytes() == b'ORIGINAL' and not list(folder.glob('*.moonxpt-*'))
        out.unlink()
        passed('A14')
        process = subprocess.run([EXE, 'write', str(data), '--metadata', str(meta), '--output', str(out),
                                  '--allow-ambiguous-tail'], capture_output=True, text=True, timeout=15)
        assert process.returncode == 0, process.stderr
        allowed = json.loads(process.stdout)
        assert json.loads(process.stderr)['kind'] == 'warning'
        assert allowed['row_count'] == 2 and allowed['member_count'] == 1
        assert allowed['diagnostics'][0]['code'] == 'E_V5_WRITER_AMBIGUOUS_TAIL'
        assert out.read_bytes()[880:888] == b'a       '
        assert run('inspect', out, '--json', '--count-rows', '--rows', 'A=2')['members'][0]['row_count'] == 2
        passed('A15')
        assert run('inspect', FIXTURES / 'zero-row.xpt', '--json', '--count-rows')['members'][0]['row_count'] == 0
        passed('A16')
    consumer = subprocess.run([sys.executable, str(ROOT / 'tools/test_consumer.py')], cwd=ROOT,
                              capture_output=True, text=True, check=True)
    assert 'public API consumer PASS' in consumer.stdout
    passed('A17')
    legacy = run('inspect', ROOT / 'tests/fixtures/xport-multi.xpt', '--json', '--count-rows',
                 '--encoding', 'windows-1252', '--tail-policy', 'trim')['members']
    assert [m['row_count'] for m in legacy] == [3, 2]
    assert legacy[0]['boundary_status'] == 'ambiguous'
    passed('A18')
    run('inspect', FIXTURES / 'nul-padding.xpt', '--json', '--rows', 'A=1', code=2)
    nul = run('inspect', FIXTURES / 'nul-padding.xpt', '--json', '--rows', 'A=1', '--padding-policy', 'nul')
    assert nul['members'][0]['boundary']['padding_kind'] == 'space_or_nul_compatibility'
    for file, code in [('truncated-padding.xpt', 'E_V5_TRUNCATED_PADDING'),
                       ('truncated-observation.xpt', 'E_V5_TRUNCATED_OBSERVATION'),
                       ('truncated-member-header.xpt', 'E_V5_INVALID_MEMBER_HEADER')]:
        hints = ['--rows', 'A=1']
        assert run('inspect', FIXTURES / file, '--json', *hints, code=2)['code'] == code
    return {'status': 'passed', 'test_ids': result, 'fixtures': 14,
            'boundary': 'CLI assertions plus source compatibility exercised by the original tools/check.py consumer and A17 MoonBit unit test'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = test()
    text = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(text)
    print(text, end='')
