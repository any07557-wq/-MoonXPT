"""Read-only SHA-256 verification of a v0.2.0 evidence directory and its raw bundles."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(folder):
    records = json.loads((folder / 'manifest.json').read_text())['files']
    names = {r['file'] for r in records}
    assert len(names) == len(records)
    assert names | {'manifest.json'} == {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
    bundles = 0
    for record in records:
        path = PurePosixPath(record['file'])
        assert not path.is_absolute() and '..' not in path.parts
        data = (folder / path).read_bytes()
        assert len(data) == record['bytes'] and sha(data) == record['sha256'], str(path)
        if path.suffix == '.zip':
            with zipfile.ZipFile(folder / path) as archive:
                if 'BUNDLE-MANIFEST.json' not in archive.namelist():
                    continue
                entries = archive.infolist()
                assert len(entries) == len({e.filename for e in entries})
                contents = json.loads(archive.read('BUNDLE-MANIFEST.json'))['files']
                assert {r['file'] for r in contents} | {'BUNDLE-MANIFEST.json'} == set(archive.namelist())
                for item in contents:
                    name = PurePosixPath(item['file'])
                    assert not name.is_absolute() and '..' not in name.parts
                    raw = archive.read(str(name))
                    assert len(raw) == item['bytes'] and sha(raw) == item['sha256'], str(name)
                bundles += 1
    return {'status': 'passed', 'files': len(records), 'bundles_verified': bundles,
            'boundary': 'Archive integrity only; no new product/oracle/SAS test execution.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.directory.resolve()), indent=2))
