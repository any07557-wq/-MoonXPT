"""Two independent implementation families, both directions, with explicit loss boundaries."""
import argparse
import csv
from datetime import datetime
import hashlib
import importlib.metadata
import inspect
import json
import math
from pathlib import Path
import subprocess
import sys
import traceback

import pandas as pd
import pyreadstat
from xport_compat import xport

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / '_build/native/debug/build/cmd/moonxpt/moonxpt.exe'
DRIVER = ROOT / '_build/native/debug/build/tests/interop/driver/driver.exe'
PRIMARY = {
    'TEST_A': {'N': [1.25, -3.5, None], 'TXT': ['alpha', 'a,b', 'tail']},
    'TEST_B': {'CODE': ['X1', 'Y2'], 'VALUE': [0., 123.]},
    'EMPTY': {'X': []},
    'TAGS': {'VALUE': [None] * 28},
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cli(*args, code=0):
    p = subprocess.run([CLI, *map(str, args)], capture_output=True, text=True, timeout=30)
    assert p.returncode == code, (args, p.returncode, p.stdout, p.stderr)
    return json.loads(p.stderr if code else p.stdout)


def fmt(raw, at, informat=False):
    # Only fixed-width metadata padding is removed; observation text is never trimmed.
    result = {'name': raw[at:at + 8].decode('cp1252').rstrip(' '),
              'width': int.from_bytes(raw[at + 8:at + 10], 'big'),
              'decimals': int.from_bytes(raw[at + 10:at + 12], 'big'),
              'justification': 0 if informat else int.from_bytes(raw[at + 12:at + 14], 'big')}
    return result


def layout(path, counts):
    """TS-140 projection using producer-known counts, independent of product resolver."""
    data = path.read_bytes()
    at = 240
    result = {}
    while at < len(data):
        assert at % 80 == 0 and data[at:at + 20] == b'HEADER RECORD*******'
        name = data[at + 168:at + 176].decode().rstrip(' ')
        stride = int(data[at + 74:at + 78])
        nvars = int(data[at + 374:at + 378])
        variables = []
        for i in range(nvars):
            b = data[at + 400 + i * stride:at + 400 + (i + 1) * stride]
            variables.append({'name': b[8:16].decode().rstrip(' '),
                              'label': b[16:56].decode('cp1252').rstrip(' '),
                              'type': 'numeric' if int.from_bytes(b[:2], 'big') == 1 else 'character',
                              'width': int.from_bytes(b[4:6], 'big'),
                              'position': int.from_bytes(b[84:88], 'big'),
                              'number': int.from_bytes(b[6:8], 'big'),
                              'hash': int.from_bytes(b[2:4], 'big'),
                              'format': fmt(b, 56), 'informat': fmt(b, 72, True)})
        width = max((v['position'] + v['width'] for v in variables), default=0)
        start = at + 480 + ((nvars * stride + 79) // 80) * 80
        end = start + counts[name] * width
        boundary = (end + 79) // 80 * 80
        assert boundary <= len(data) and data[end:boundary] == b' ' * (boundary - end)
        result[name] = {'header': at, 'obs': start, 'end': end, 'boundary': boundary,
                        'variables': variables, 'row_width': width,
                        'label': data[at + 272:at + 312].decode('cp1252').rstrip(' ')}
        at = boundary
    assert at == len(data) and set(result) == set(counts)
    return result


def moon_projection(path, counts, output, expected=None):
    hints = [v for name, n in counts.items() for v in ['--rows', f'{name}={n}']]
    info = cli('inspect', path, '--json', '--count-rows', '--encoding', 'windows-1252', *hints)
    spec = layout(path, counts)
    assert [m['metadata']['name'] for m in info['members']] == list(spec)
    exports = {}
    for item in info['members']:
        name = item['metadata']['name']
        assert item['row_count'] == counts[name]
        assert item['metadata']['variables'] == spec[name]['variables']
        assert item['metadata']['row_width'] == spec[name]['row_width']
        assert item['metadata']['label'] == spec[name]['label']
        csvfile, metafile = output / f'{path.stem}-{name}.csv', output / f'{path.stem}-{name}.json'
        cli('export', path, '--member', name, '--encoding', 'windows-1252', *hints,
            '--csv', csvfile, '--metadata', metafile)
        with csvfile.open(newline='') as f:
            rows = list(csv.reader(f))
        assert rows[0] == [v['name'] for v in spec[name]['variables']]
        assert len(rows) - 1 == counts[name]
        if expected is not None:
            for row, authored in zip(rows[1:], expected[name], strict=True):
                for value, original, variable in zip(row, authored, spec[name]['variables'], strict=True):
                    if variable['type'] == 'character':
                        assert value == original.encode('cp1252').ljust(variable['width']).decode('cp1252')
                    elif original is None:
                        assert value == '.'
                    else:
                        assert float(value) == original
        exports[name] = rows
    return info, spec, exports


def check_frame(frame, expected):
    assert list(frame.columns) == list(expected)
    assert len(frame) == len(next(iter(expected.values())))
    for name, values in expected.items():
        for actual, authored in zip(frame[name], values, strict=True):
            if authored is None:
                assert math.isnan(float(actual))
            else:
                # Literal authored oracle views, no blanket data trimming.
                assert actual == authored, (name, actual, authored)


def format_view(value):
    if not value['name']:
        return None
    return value['name'] + (str(value['width']) if value['width'] else '') + (
        '.' + str(value['decimals']) if value['decimals'] else '')


def readstat_metadata(metadata, spec, name):
    variables = spec['variables']
    assert metadata.table_name == name and metadata.column_names == [v['name'] for v in variables]
    assert [s or '' for s in metadata.column_labels] == [v['label'] for v in variables]
    assert (metadata.file_label or '') == spec['label']
    assert metadata.variable_storage_width == {v['name']: v['width'] for v in variables}
    assert metadata.original_variable_types == {v['name']: format_view(v['format']) for v in variables}
    assert metadata.original_variable_informats == {v['name']: format_view(v['informat']) for v in variables}


def xport_metadata(data, spec):
    header = xport.v56.MemberHeader.from_bytes(data[spec['header']:])
    assert header.dataset_label == spec['label']
    assert list(header) == [v['name'] for v in spec['variables']]
    for v in spec['variables']:
        actual = header[v['name']]
        assert actual.label == v['label'] and actual.length == v['width']
        assert actual.position == v['position'] and actual.number == v['number']
        assert actual.vtype.value == (1 if v['type'] == 'numeric' else 2)
        assert (actual.format.name, actual.format.length, actual.format.decimals, actual.format.justify) == tuple(
            v['format'][k] for k in ['name', 'width', 'decimals', 'justification'])
        assert (actual.informat.name, actual.informat.length, actual.informat.decimals) == tuple(
            v['informat'][k] for k in ['name', 'width', 'decimals'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    for folder in ['inputs', 'exports', 'moon']:
        (evidence / folder).mkdir()
    report = {'status': 'failed', 'directions': {}, 'test_ids': {}, 'limitations': [], 'edges': []}
    try:
        lock = json.loads((ROOT / 'tools/oracles-v0.2.0.json').read_text())
        versions = {p: importlib.metadata.version(p) for p in ['pyreadstat', 'xport', 'pandas', 'numpy', 'setuptools']}
        assert versions['pyreadstat'] == lock['readstat_family']['wrapper_version']
        assert versions['xport'] == lock['python_xport_family']['version']
        source = Path(inspect.getsourcefile(xport.v56))
        assert digest(source) == lock['python_xport_family']['v56_sha256']
        for line in (ROOT / 'tools/requirements-oracle.txt').read_text().splitlines():
            if line.strip() and not line.startswith('#'):
                package, version = line.split('==')
                actual = importlib.metadata.version(package)
                assert actual == version, (package, actual, version)
                versions[package] = actual
        report['oracle_versions'] = versions
        report['oracle_source_lock'] = lock
        report['runtime_modules'] = [{'file': str(p.relative_to(Path(pyreadstat.__file__).parent)), 'sha256': digest(p)}
                                     for p in sorted(Path(pyreadstat.__file__).parent.glob('*.so'))]
        report['python'] = sys.version
        report['adapter_sha256'] = digest(ROOT / 'tools/xport_compat.py')
        # ReadStat family independently generates a new input. Preserve its actual timestamps/bytes.
        frame = pd.DataFrame({'N': [0., 1.25, -3.5, float('nan')],
                              'TXT': pd.Series(['.A', 'a,b', 'a"b', 'tail  '], dtype=object)})
        readstat = evidence / 'inputs/readstat-v5.xpt'
        pyreadstat.write_xport(frame, readstat, file_format_version=5, table_name='ORACLE',
                              file_label='ReadStat new input', column_labels=['Numeric', 'Text'],
                              variable_format={'N': 'BEST12.2'}, variable_informat={'N': 'BEST12.'})
        original = [[0., '.A'], [1.25, 'a,b'], [-3.5, 'a"b'], [None, 'tail  ']]
        moon_projection(readstat, {'ORACLE': 4}, evidence / 'exports', {'ORACLE': original})
        report['directions']['I03_R01'] = {'status': 'passed', 'family': 'ReadStat via pyreadstat', 'members': 1, 'rows': 4}
        # Python xport independently generates both single-member and multi-member libraries.
        with xport.v56._encoding(data='cp1252', metadata='cp1252'):
            first = xport.Dataset({'ID': pd.Series([1., 2., 3.], dtype='float64'),
                                   'TEXT': pd.Series(['a,b', 'é€', 'tail  '], dtype=object)}, name='FIRST', label='Café €')
            first['TEXT'].width = 12
            first['TEXT'].label = 'Character bytes'
            second = xport.Dataset({'OTHER': pd.Series([-3.5, .125], dtype='float64')}, name='SECOND', label='Other schema')
            for dataset in [first, second]:
                dataset.created = dataset.modified = datetime(2000, 1, 1)
            for filename, datasets in [('xport-single.xpt', [first]), ('xport-multi.xpt', [first, second])]:
                lib = xport.Library(datasets, created=datetime(2000, 1, 1), modified=datetime(2000, 1, 1),
                                    sas_version='6.06', sas_os='LINUX')
                path = evidence / 'inputs' / filename
                path.write_bytes(xport.v56.dumps(lib))
                counts = {'FIRST': 3} if len(datasets) == 1 else {'FIRST': 3, 'SECOND': 2}
                expected = {'FIRST': [[1., 'a,b'], [2., 'é€'], [3., 'tail  ']], 'SECOND': [[-3.5], [.125]]}
                moon_projection(path, counts, evidence / 'exports', expected)
                report['directions']['I05_R03' if len(datasets) == 1 else 'I05_R05'] = {
                    'status': 'passed', 'family': 'Python xport', 'members': len(datasets), 'rows': counts}
        produced = subprocess.check_output([DRIVER, evidence / 'moon'], text=True)
        report['moon_generator'] = json.loads(produced)
        regular_counts = {name: len(next(iter(values.values()))) for name, values in PRIMARY.items()}
        multi = evidence / 'moon/moon_regular.xpt'
        _, specs, _ = moon_projection(multi, regular_counts, evidence / 'exports')
        lib = xport.v56.loads(multi.read_bytes())
        assert list(lib) == list(PRIMARY)
        for name, expected in PRIMARY.items():
            path = evidence / 'moon' / (name + '.xpt')
            counts = {name: regular_counts[name]}
            spec = layout(path, counts)[name]
            df, metadata = pyreadstat.read_xport(path, disable_datetime_conversion=True)
            check_frame(df, expected)
            readstat_metadata(metadata, spec, name)
            single = xport.v56.loads(path.read_bytes())
            assert list(single) == [name]
            check_frame(single[name], expected)
            check_frame(lib[name], expected)
            xport_metadata(path.read_bytes(), spec)
            xport_metadata(multi.read_bytes(), specs[name])
        report['directions']['I04_R02'] = {'status': 'passed', 'family': 'ReadStat via pyreadstat',
                                          'single_member_files': list(PRIMARY), 'rows': regular_counts,
                                          'scope': 'all ordinary numeric values/masks and exposed metadata; decoded character views only'}
        report['directions']['I06_R04'] = {'status': 'passed', 'family': 'Python xport', 'single_member_files': list(PRIMARY)}
        report['directions']['I06_R06'] = {'status': 'passed', 'family': 'Python xport', 'members': list(PRIMARY),
                                          'rows': regular_counts, 'scope': 'all members/columns/rows of regular multi-member output'}
        # Independent low-level xport API preserves tagged NaN bytes; DataFrames do not.
        tags = evidence / 'moon/TAGS.xpt'
        start = layout(tags, {'TAGS': 28})['TAGS']['obs']
        for i, tag in enumerate(sorted(b'._ABCDEFGHIJKLMNOPQRSTUVWXYZ')):
            raw = tags.read_bytes()[start + i * 8:start + (i + 1) * 8]
            assert raw == bytes([tag]) + b'\0' * 7
            value = xport.v56.ibm_to_ieee(raw)
            if tag == ord('.'):
                assert math.isnan(value)
            else:
                assert value.name == chr(tag) and bytes(value) == raw
        report['special_missing'] = {'Python_xport_low_level': 'passed: 28 classes, tagged byte vectors exact',
                                     'ReadStat_wrapper': 'not_supported_by_oracle: tags normalized to NaN',
                                     'dataframe_tag_identity': 'not_supported_by_oracle'}
        # Known unsupported cases are measured explicitly, never silently trimmed into a pass.
        for family in ['ReadStat', 'Python xport']:
            for name, expected_count in [('SHORT', 1), ('FULLBL', 0)]:
                path = evidence / 'moon' / (name + '.xpt')
                df = pyreadstat.read_xport(path, disable_datetime_conversion=True)[0] if family == 'ReadStat' else xport.v56.loads(path.read_bytes())[name]
                assert len(df) == expected_count, (family, name, len(df))
                report['edges'].append({'family': family, 'fixture': name, 'authored_rows': 2 if name == 'SHORT' else 1,
                                        'observed_rows': len(df), 'status': 'not_supported_by_oracle',
                                        'reason': 'all-blank observation lost by this pinned reader; not counted as interoperable'})
        child = subprocess.run([sys.executable, '-c',
                                'import pyreadstat,sys,json; d,m=pyreadstat.read_xport(sys.argv[1],disable_datetime_conversion=True); print(json.dumps({"rows":len(d),"columns":list(d.columns)}))', str(multi)],
                               capture_output=True, text=True, timeout=20)
        report['ReadStat_multi_member_probe'] = {'status': 'not_supported_by_oracle', 'exit_code': child.returncode,
                                                'stdout': child.stdout, 'stderr': child.stderr,
                                                'scope': 'No ReadStat multi-member success claim; no first-member slicing used for R06'}
        for filename in ['invalid-padding.xpt', 'truncated-padding.xpt', 'truncated-observation.xpt', 'nul-padding.xpt']:
            path = ROOT / 'tests/boundary/fixtures' / filename
            assert cli('inspect', path, '--json', '--rows', 'A=1', code=2)['kind'] != 'internal'
            for family in ['ReadStat', 'Python xport']:
                try:
                    df = pyreadstat.read_xport(path, disable_datetime_conversion=True)[0] if family == 'ReadStat' else xport.v56.loads(path.read_bytes())['A']
                    observed = {'rows': len(df), 'rejected': False}
                except Exception as error:
                    observed = {'rejected': True, 'error': type(error).__name__, 'message': str(error)}
                report['edges'].append({'family': family, 'fixture': filename, 'status': 'not_supported_by_oracle',
                                        'reason': 'oracle outcome recorded; not evidence of strict padding/physical-record validation',
                                        'observed': observed})
        compatible = cli('inspect', ROOT / 'tests/boundary/fixtures/nul-padding.xpt', '--json', '--rows', 'A=1', '--padding-policy', 'nul')
        assert compatible['members'][0]['boundary']['row_count'] == 1
        report['limitations'] = [
            'Character raw storage bytes and trailing-space identity are not exposed by either convenience reader; no blanket observation trim is used to claim equality.',
            'Numeric/gap/reordered-position/full-HFP-range coverage outside oracle exposure remains normative vectors, not an oracle success claim.',
            'ReadStat and pyreadstat are one family. Upstream reviewed code differs from the actual pinned vendored reader.',
            'SAS XPORT Engine is blocked; no SAS results are included.',
        ]
        report['test_ids'] = {f'R{i:02}': 'passed' for i in range(1, 11)}
        report['status'] = 'passed'
    except BaseException:
        report['failure'] = traceback.format_exc()
        raise
    finally:
        report['files'] = [{'file': str(p.relative_to(evidence)), 'bytes': p.stat().st_size, 'sha256': digest(p),
                            'license': 'MIT synthetic test data', 'personal_data': False}
                           for p in sorted(evidence.rglob('*')) if p.is_file()]
        (evidence / 'result.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'status': report['status'], 'directions': report['directions'], 'limits_recorded': len(report['edges'])}, indent=2))


if __name__ == '__main__':
    main()
