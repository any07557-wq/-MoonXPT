"""Offline verification of the archived remote CI evidence; no test execution."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[4]
FOLDER = Path(__file__).resolve().parent
HEAD = 'b0d622d7f1e555b9c32cebf991682d9a7d25de0f'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def unpack(raw):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        assert z.testzip() is None
        assert len(z.namelist()) == len(set(z.namelist()))
        for name in z.namelist():
            p = PurePosixPath(name)
            assert not p.is_absolute() and '..' not in p.parts and '\\' not in name
        return {n: z.read(n) for n in z.namelist() if not n.endswith('/')}


def manifest(files, name):
    prefix = name[:-len(PurePosixPath(name).name)]
    rows = json.loads(files[name])['files']
    names = set()
    for row in rows:
        p = PurePosixPath(row['file'])
        assert not p.is_absolute() and '..' not in p.parts
        target = prefix + str(p)
        assert target not in names
        names.add(target)
        assert sha(files[target]) == row['sha256'], target
        if 'bytes' in row:
            assert len(files[target]) == row['bytes'], target
    assert names == {n for n in files if n.startswith(prefix)} - {name}


def main():
    outer = {p.relative_to(FOLDER).as_posix(): p.read_bytes()
             for p in FOLDER.rglob('*') if p.is_file()}
    manifest(outer, 'manifest.json')
    lock = json.loads(subprocess.check_output(['git', 'show', HEAD + ':tools/toolchain.json'], cwd=ROOT))
    corpus_lock = json.loads(subprocess.check_output(['git', 'show', HEAD + ':tests/corpus.json'], cwd=ROOT))
    corpus_digests = {r['sha256'] for r in corpus_lock}
    artifacts_verified = 0
    manifests_verified = 0
    sdk_prefixes = set()
    for filename in sorted(outer):
        if not filename.startswith('raw-') or not filename.endswith('.zip'):
            continue
        bundle = unpack(outer[filename])
        manifest(bundle, 'BUNDLE-MANIFEST.json')
        run = json.loads(bundle['run.json'])
        assert run['head_sha'] == HEAD and run['head_branch'] == 'work/v0.2.0-boundary'
        assert run['status'] == 'completed' and run['conclusion'] == 'success' and run['run_attempt'] == 1
        jobs = {j['name']: j['conclusion'] for j in json.loads(bundle['jobs.json'])['jobs']}
        assert jobs['sas-interop'] == 'skipped'
        required = {'offline-core', 'fixtures-interop', 'release-repro'}
        if run['event'] == 'workflow_dispatch':
            required.add('public-corpus')
        else:
            assert run['event'] == 'push' and jobs['public-corpus'] == 'skipped'
        assert all(jobs[name] == 'success' for name in required)
        assert len(unpack(bundle['logs.zip'])) > 0
        rows = json.loads(bundle['artifacts.json'])['artifacts']
        assert len(rows) == len(required)
        for artifact in rows:
            job = artifact['name'].removesuffix(f"-{run['id']}-1")
            assert job in required
            raw = bundle[artifact['name'] + '.zip']
            assert artifact['digest'] == 'sha256:' + sha(raw) and not artifact['expired']
            files = unpack(raw)
            for name in files:
                if PurePosixPath(name).name == 'manifest.json':
                    manifest(files, name)
                    manifests_verified += 1
            result = json.loads(files['result.json'])
            assert result['status'] == 'passed'
            prefix = 'offline/' if job == 'release-repro' else ''
            receipt = json.loads(files[prefix + 'result.json'])
            assert receipt['status'] == 'passed' and receipt['source_parent_commit'] == HEAD
            assert receipt['sas'] == 'blocked' and len(receipt['source_files']) == 95
            assert all(step['exit_code'] == 0 for step in receipt['steps'])
            assert len({r['file'] for r in receipt['source_files']}) == 95
            for row in receipt['source_files']:
                blob = subprocess.check_output(['git', 'show', HEAD + ':' + row['file']], cwd=ROOT)
                assert sha(blob) == row['sha256'], row['file']
            sdk = json.loads(files[prefix + 'sdk-install.json'])
            assert sdk['result'] == 'PASS' and not sdk['existing_sdk_read'] and not sdk['download_cache_reused']
            assert sdk['archive_version'] == lock['archive_version']
            assert sdk['native']['sha256'] == lock['archive_sha256'] and sdk['core']['sha256'] == lock['core_sha256']
            assert all(lock[k] in sdk['version_output'] for k in ('moon', 'moon_commit', 'moonc'))
            sdk_prefixes.add(sdk['prefix'])
            if job in {'offline-core', 'release-repro'}:
                assert b'Total tests: 81, passed: 81, failed: 0.' in files[prefix + 'legacy-and-unit.log']
            if job == 'release-repro':
                assert result['source_commit'] == HEAD and not result['project_build_cache_reused']
            if job == 'public-corpus':
                corpus = json.loads(files['corpus-results.json'])
                assert len(corpus) == 3 and sum(r['cells'] for r in corpus) == 620612
                assert max(r['max_ulp'] for r in corpus) == 0
                assert {r['sha256'] for r in corpus} == corpus_digests
                assert all(r['result'] == 'PASS' and r['metadata'] == 'exact declared attributes' for r in corpus)
            if job == 'fixtures-interop':
                interop = json.loads(files['interop/result.json'])
                assert interop['status'] == 'passed' and len(interop['directions']) == 6
                assert all(r['status'] == 'passed' for r in interop['directions'].values())
                assert interop['ReadStat_multi_member_probe']['status'] == 'not_supported_by_oracle'
            artifacts_verified += 1
    assert artifacts_verified == len(sdk_prefixes) == 7
    print(json.dumps({'status': 'passed', 'runs': 2, 'artifacts': artifacts_verified,
                      'artifact_manifests': manifests_verified, 'fresh_sdk_receipts': len(sdk_prefixes),
                      'source_files_per_receipt': 95, 'source_commit': HEAD,
                      'sas': 'blocked; skipped is not passed',
                      'scope': 'Offline integrity and recorded-result verification; no new CI or oracle execution'}, indent=2))


if __name__ == '__main__':
    main()
