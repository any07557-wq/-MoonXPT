"""Independent TS-140 layout vectors; no MoonXPT parser/writer is imported."""
import argparse
import hashlib
import json
from pathlib import Path


def header(kind):
    return b'HEADER RECORD*******' + kind.encode().ljust(8) + b'HEADER RECORD!!!!!!!' + b'0' * 30 + b'  '


def library():
    first = bytearray(b' ' * 80)
    first[:24] = b'SAS     SAS     SASLIB  '
    first[24:32] = b'0.1     '
    first[32:40] = b'MOONXPT '
    first[64:80] = b'01JAN00:00:00:00'
    return header('LIBRARY') + first + b'01JAN00:00:00:00' + b' ' * 64


def member_header(name, widths, descriptor_size=140):
    first = bytearray(header('MEMBER'))
    first[65:68] = b'160'
    first[74:78] = f'{descriptor_size:04}'.encode()
    real = bytearray(b' ' * 80)
    real[:24] = b'SAS     ' + name.encode().ljust(8) + b'SASDATA '
    real[24:32] = b'0.1     '
    real[32:40] = b'MOONXPT '
    real[64:80] = b'01JAN00:00:00:00'
    namestr = bytearray(header('NAMESTR'))
    namestr[54:58] = f'{len(widths):04}'.encode()
    descriptors = bytearray()
    position = 0
    for number, width in enumerate(widths, 1):
        raw = bytearray(140)
        raw[:2] = (2).to_bytes(2, 'big')
        raw[4:6] = width.to_bytes(2, 'big')
        raw[6:8] = number.to_bytes(2, 'big')
        raw[8:64] = b' ' * 56
        raw[8:16] = f'C{number}'.encode().ljust(8)
        raw[72:80] = b' ' * 8
        raw[84:88] = position.to_bytes(4, 'big')
        descriptors += raw[:descriptor_size]
        position += width
    descriptors += b' ' * (-len(descriptors) % 80)
    return first + header('DSCRPTR') + real + b'01JAN00:00:00:00' + b' ' * 64 + namestr + descriptors + header('OBS')


def file_bytes(members):
    return library() + b''.join(member_header(name, widths) + data + b' ' * (-len(data) % 80)
                                for name, widths, data in members)


def build_cases():
    wide = file_bytes([('A', [81], b'x' * 81)])
    multi = file_bytes([('A', [81], b'a' * 81), ('B', [80], b'b' * 80)])
    return {
        'short-unique.xpt': (file_bytes([('A', [3], b'abc' * 26)]), ['B03', 'A02']),
        'short-ambiguous.xpt': (file_bytes([('A', [4], b'a       ')]), ['B19', 'A04', 'A06']),
        'wide-unique.xpt': (wide, ['B07', 'A03']),
        'multi-unique.xpt': (multi, ['M01', 'A07']),
        'multi-ambiguous-rows.xpt': (file_bytes([('A', [4], b'a       '), ('B', [80], b'b' * 80)]), ['M07']),
        'polyglot.xpt': (file_bytes([('POLYGLOT', [160] * 4, member_header('FAKE', [8]))]), ['M18']),
        'invalid-padding.xpt': (wide[:-1] + b'X', ['B11', 'A05']),
        'nul-padding.xpt': (wide[:-79] + b'\0' * 79, ['B11', 'R10']),
        'truncated-padding.xpt': (wide[:-1], ['B13']),
        'truncated-observation.xpt': (wide[:880 + 80], ['B12']),
        'truncated-member-header.xpt': (multi[:1140], ['M16']),
        'trailing-garbage.xpt': (wide + b'X' * 80, ['M17']),
        'wide-blank.xpt': (file_bytes([('A', [80], b' ' * 80)]), ['B06', 'A15']),
        'zero-row.xpt': (file_bytes([('A', [8], b'')]), ['B01', 'A16']),
    }


def manifest():
    return [dict(file=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), test_ids=ids,
                 producer='Python stdlib TS-140 layout vector, generate.py', tool='Python 3 stdlib',
                 license='MIT, synthetic MoonXPT test data', personal_data=False,
                 purpose='validity, ambiguity or deliberate corruption as named; not SAS-generated')
            for name, (data, ids) in build_cases().items()]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', type=Path)
    args = parser.parse_args()
    if bool(args.output) == bool(args.check):
        parser.error('choose --output NEW_DIRECTORY or --check EXISTING_DIRECTORY')
    folder = args.output or args.check
    if args.output:
        folder.mkdir(parents=True, exist_ok=False)
        for name, (data, _) in build_cases().items():
            (folder / name).write_bytes(data)
        (folder / 'manifest.json').write_text(json.dumps(manifest(), indent=2) + '\n')
    else:
        assert json.loads((folder / 'manifest.json').read_text()) == manifest()
        for name, (data, _) in build_cases().items():
            assert (folder / name).read_bytes() == data, name
    print(f'passed: {len(build_cases())} independently generated boundary fixtures')
