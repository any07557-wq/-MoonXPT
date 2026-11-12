"""Read-only remote CI collection; preserve original API responses and ZIP bytes."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

REPO = 'any07557-wq/-MoonXPT'
HEAD = 'b0d622d7f1e555b9c32cebf991682d9a7d25de0f'
BRANCH = 'work/v0.2.0-boundary'
EVENTS = {43167635468: 'push', 43167683870: 'workflow_dispatch'}
BASE = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def api(endpoint):
    return subprocess.check_output(['gh', 'api', 'repos/' + REPO + '/' + endpoint])


def write(path, data):
    if path.exists():
        assert path.read_bytes() == data, f'Refusing to overwrite different evidence: {path}'
    else:
        path.write_bytes(data)


def zip_contents(data):
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        assert z.testzip() is None
        names = z.namelist()
        assert len(names) == len(set(names))
        for n in names:
            p = PurePosixPath(n)
            assert not p.is_absolute() and '..' not in p.parts and '\\' not in n
        return {n: z.read(n) for n in names if not n.endswith('/')}


def verify_manifests(files):
    verified = []
    for name, raw in sorted(files.items()):
        if PurePosixPath(name).name != 'manifest.json':
            continue
        prefix = name[:-len('manifest.json')]
        rows = json.loads(raw)['files']
        listed = set()
        for row in rows:
            p = PurePosixPath(row['file'])
            assert not p.is_absolute() and '..' not in p.parts
            target = prefix + str(p)
            assert target not in listed
            listed.add(target)
            assert sha(files[target]) == row['sha256'], target
            if 'bytes' in row:
                assert len(files[target]) == row['bytes'], target
        actual = {n for n in files if n.startswith(prefix)} - {name}
        assert listed == actual, (name, listed ^ actual)
        verified.append({'file': name, 'entries': len(rows)})
    assert verified
    return verified


def source_identities():
    paths = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', HEAD], text=True).splitlines()
    result = {}
    for path in paths:
        p = PurePosixPath(path)
        include = (p.suffix in {'.mbt', '.c', '.py', '.pkg', '.yml', '.yaml'} or p.name in
                   {'moon.mod', 'requirements-oracle.txt', 'toolchain.json', 'oracles-v0.2.0.json'})
        scope = len(p.parts) == 1 or p.parts[0] in {'cmd', 'exchange', 'platform', 'examples', 'tests', 'tools', '.github'}
        if include and scope:
            result[path] = sha(subprocess.check_output(['git', 'show', HEAD + ':' + path]))
    return result


def collect(run_id):
    raw_run = api(f'actions/runs/{run_id}')
    run = json.loads(raw_run)
    assert run['head_sha'] == HEAD and run['head_branch'] == BRANCH
    assert run['event'] == EVENTS[run_id]
    if run['status'] != 'completed':
        print(json.dumps({'run': run_id, 'status': run['status'], 'collection': 'not yet attempted'}), flush=True)
        return
    assert run['run_attempt'] == 1
    target = BASE / str(run_id)
    target.mkdir(exist_ok=True)
    write(target / 'run.json', raw_run)
    raw_jobs = api(f'actions/runs/{run_id}/jobs?per_page=100')
    jobs = json.loads(raw_jobs)
    assert jobs['total_count'] == len(jobs['jobs']) == 5
    write(target / 'jobs.json', raw_jobs)
    raw_artifacts = api(f'actions/runs/{run_id}/artifacts?per_page=100')
    artifacts = json.loads(raw_artifacts)
    assert artifacts['total_count'] == len(artifacts['artifacts'])
    write(target / 'artifacts.json', raw_artifacts)
    raw_logs = api(f'actions/runs/{run_id}/logs')
    logs = zip_contents(raw_logs)
    write(target / 'logs.zip', raw_logs)
    expected = {'offline-core', 'fixtures-interop', 'release-repro'}
    if run['event'] == 'workflow_dispatch':
        expected.add('public-corpus')
    conclusions = {j['name']: j['conclusion'] for j in jobs['jobs']}
    report = {'run_id': run_id, 'url': run['html_url'], 'event': run['event'], 'head': HEAD,
              'conclusion': run['conclusion'], 'jobs': conclusions,
              'log_files': len(logs), 'logs_sha256': sha(raw_logs), 'artifacts': [],
              'sas_validation': 'blocked; job skipped; no legal SAS environment supplied'}
    expected_sources = source_identities()
    for artifact in artifacts['artifacts']:
        assert not artifact['expired']
        name = artifact['name']
        job = name.removesuffix(f'-{run_id}-1')
        assert job in expected
        raw = api(f"actions/artifacts/{artifact['id']}/zip")
        digest = 'sha256:' + sha(raw)
        assert digest == artifact['digest'], (name, digest, artifact['digest'])
        files = zip_contents(raw)
        filename = name + '.zip'
        write(target / filename, raw)
        manifests = verify_manifests(files)
        root = json.loads(files['result.json'])
        assert root['status'] == 'passed', name
        receipt_name = 'offline/result.json' if job == 'release-repro' else 'result.json'
        receipt = json.loads(files[receipt_name])
        assert receipt['status'] == 'passed' and receipt['source_parent_commit'] == HEAD
        observed = {x['file']: x['sha256'] for x in receipt['source_files']}
        assert len(observed) == len(receipt['source_files']) and observed == expected_sources
        assert receipt['sas'] == 'blocked'
        sdk_path = 'offline/sdk-install.json' if job == 'release-repro' else 'sdk-install.json'
        sdk = json.loads(files[sdk_path])
        item = {'job': job, 'id': artifact['id'], 'file': filename, 'bytes': len(raw),
                'sha256': sha(raw), 'github_digest_verified': True, 'files': len(files),
                'manifests': manifests, 'source_files_verified': len(observed),
                'sdk_receipt_path': sdk_path, 'sdk_receipt': sdk,
                'result': root, 'steps': receipt['steps']}
        if job == 'release-repro':
            assert root['source_commit'] == HEAD and not root['project_build_cache_reused']
        if job == 'public-corpus':
            rows = json.loads(files['corpus-results.json'])
            item['public_corpus'] = rows
            assert sum(r['cells'] for r in rows) == 620612
            assert max(r['max_ulp'] for r in rows) == 0
        if job == 'fixtures-interop':
            item['interop'] = json.loads(files['interop/result.json'])
        if job == 'offline-core':
            item['api_cli'] = json.loads(files['api-cli.json'])
        report['artifacts'].append(item)
    assert len(report['artifacts']) == len(expected)
    assert {a['job'] for a in report['artifacts']} == expected
    assert run['conclusion'] == 'success'
    assert all(conclusions[k] == 'success' for k in expected)
    assert conclusions['sas-interop'] == 'skipped'
    if run['event'] == 'push':
        assert conclusions['public-corpus'] == 'skipped'
    write(target / 'verification.json', (json.dumps(report, indent=2) + '\n').encode())
    print(json.dumps({'run': run_id, 'status': 'verified', 'jobs': conclusions,
                      'artifacts': len(report['artifacts']), 'log_files': len(logs)}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', type=int, nargs='+', choices=EVENTS)
    for value in parser.parse_args().runs:
        collect(value)
