"""Prepared real-SAS execution gate; never simulates SAS or fabricates a LOG."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MEMBERS = {'TEST_A': 3, 'TEST_B': 2, 'EMPTY': 0, 'SHORT': 2, 'FULLBL': 1, 'TAGS': 28}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sas', required=True, type=Path)
    parser.add_argument('--work-dir', required=True, type=Path)
    parser.add_argument('--confirm-xport-engine-authorized', action='store_true', required=True)
    args = parser.parse_args()
    sas = args.sas.resolve()
    if not sas.is_file() or not os.access(sas, os.X_OK):
        parser.error('real SAS executable is missing or not executable')
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=False)
    for folder in ['ref', 'imported', 'moon', 'programs', 'exports']:
        (work / folder).mkdir()
    record = {'status': 'prepared_not_verified', 'sas_executable': str(sas),
              'authorization': 'operator supplied explicit confirmation', 'steps': []}
    env = dict(os.environ, MOONXPT_SAS_WORK=str(work))
    try:
        subprocess.run(['moon', 'build', '--target', 'native', '--deny-warn'], cwd=ROOT, check=True)
        cli = ROOT / '_build/native/debug/build/cmd/moonxpt/moonxpt.exe'
        driver = ROOT / '_build/native/debug/build/tests/interop/driver/driver.exe'
        subprocess.run([driver, work / 'moon'], cwd=ROOT, check=True)
        for script, marker in [('create_inputs.sas', 'MOONXPT_CREATE_DONE'),
                               ('read_moonxpt.sas', 'MOONXPT_READ_DONE')]:
            source = work / 'programs' / script
            shutil.copy2(ROOT / 'tests/interop/sas' / script, source)
            log = work / (script + '.log')
            listing = work / (script + '.lst')
            command = [str(sas), '-sysin', str(source), '-log', str(log), '-print', str(listing), '-noterminal']
            process = subprocess.run(command, env=env, cwd=work, capture_output=True, text=True)
            (work / (script + '.console')).write_text(process.stdout + process.stderr)
            record['steps'].append({'command': command, 'exit_code': process.returncode})
            process.check_returncode()
            text = log.read_text(errors='replace')
            assert marker in text and not re.search(r'^ERROR(?:\s|:)', text, re.M), log
            if script == 'create_inputs.sas':
                version = re.search(r'MOONXPT_SAS_VERSION=(.+)', text)
                assert version and version[1].strip(), 'missing real SAS version log'
                record['sas_version_from_log'] = version[1].strip()
                for filename, counts in [('sas_single.xpt', {'TEST_A': 3}), ('sas_multi.xpt', MEMBERS)]:
                    hints = [a for name, n in counts.items() for a in ['--rows', f'{name}={n}']]
                    raw = subprocess.check_output([cli, 'inspect', work / filename, '--json', '--count-rows', *hints])
                    (work / (filename + '.inspect.json')).write_bytes(raw)
                    members = json.loads(raw)['members']
                    assert {m['metadata']['name']: m['row_count'] for m in members} == counts
                    for name in counts:
                        for origin, source_path, source_hints in [('sas', work / filename, hints),
                                                                  ('moon', work / 'moon' / (name + '.xpt'), ['--rows', f'{name}={counts[name]}'])]:
                            stem = work / 'exports' / f'{filename}-{name}-{origin}'
                            subprocess.run([cli, 'export', source_path, '--member', name, *source_hints,
                                            '--csv', str(stem) + '.csv', '--metadata', str(stem) + '.json'], check=True)
                        prefix = work / 'exports' / f'{filename}-{name}'
                        assert Path(str(prefix) + '-sas.csv').read_bytes() == Path(str(prefix) + '-moon.csv').read_bytes()
                        left = json.loads(Path(str(prefix) + '-sas.json').read_text())['dataset']
                        right = json.loads(Path(str(prefix) + '-moon.json').read_text())['dataset']
                        assert left['name'] == right['name'] and left['variables'] == right['variables']
            else:
                comparisons = dict(re.findall(r'MOONXPT_COMPARE\|([A-Z_]+)\|(\d+)', text))
                assert set(comparisons) == set(MEMBERS) | {'SINGLE'}
                record['proc_compare_sysinfo'] = comparisons
                assert all(value == '0' for value in comparisons.values()), comparisons
        record['status'] = 'passed'
        record['scope'] = 'S01-S12 ASCII templates; S13 non-ASCII remains not_run pending session-encoding test; unsupported behavior must be recorded separately'
    except BaseException as error:
        record['status'] = 'failed'
        record['failure'] = str(error)
        raise
    finally:
        record['files'] = [{'file': p.relative_to(work).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                           for p in sorted(work.rglob('*')) if p.is_file()]
        (work / 'result.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
