"""Verify archived GitHub API/ZIP evidence against local Git objects; no network."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads(path.read_text())


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def manifest(folder):
    records = read_json(folder / "manifest.json")["files"]
    names = []
    for record in records:
        name = record["file"]
        require(not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts, "unsafe manifest path")
        data = (folder / name).read_bytes()
        require(len(data) == record["bytes"] and sha256(data) == record["sha256"], "manifest mismatch: " + name)
        names.append(name)
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
    require(len(names) == len(set(names)) and set(names) | {"manifest.json"} == actual, "manifest inventory mismatch")
    return len(records)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def verify(folder):
    if (folder / "manifest.json").exists():
        manifest(folder)
    run = read_json(folder / "run.json")
    jobs = read_json(folder / "jobs.json")
    artifacts = read_json(folder / "artifacts.json")
    require(run["status"] == "completed" and run["conclusion"] == "success", "run did not succeed")
    require(run["repository"]["full_name"] == "any07557-wq/-MoonXPT", "unexpected repository")
    require(jobs["total_count"] == len(jobs["jobs"]) == 2, "incomplete jobs response")
    job_map = {j["name"]: j for j in jobs["jobs"]}
    require(set(job_map) == {"offline", "public-corpus"}, "unexpected jobs")
    require(artifacts["total_count"] == len(artifacts["artifacts"]) == 2, "incomplete artifacts response")
    head = run["head_sha"]
    archive_digest = sha256(git("archive", head))
    summaries = []
    for artifact in artifacts["artifacts"]:
        name = artifact["name"]
        role = name.removesuffix(f"-{run['id']}-{run['run_attempt']}")
        require(role in job_map, "artifact name/run mismatch")
        job = job_map[role]
        require(job["conclusion"] == "success" and job["head_sha"] == head, "job identity/result mismatch")
        require(all(s["conclusion"] == "success" for s in job["steps"]), "job has unsuccessful steps")
        data = (folder / (name + ".zip")).read_bytes()
        require(len(data) == artifact["size_in_bytes"], "ZIP size mismatch")
        require(artifact["digest"] == "sha256:" + sha256(data), "GitHub ZIP digest mismatch")
        payload = folder / "artifacts" / name
        with zipfile.ZipFile(folder / (name + ".zip")) as bundle:
            entries = [e for e in bundle.infolist() if not e.is_dir()]
            require(len(entries) == len({e.filename for e in entries}), "duplicate ZIP entry")
            for entry in entries:
                require(not PurePosixPath(entry.filename).is_absolute() and ".." not in PurePosixPath(entry.filename).parts, "unsafe ZIP entry")
                require(bundle.read(entry) == (payload / entry.filename).read_bytes(), "ZIP/extracted mismatch")
            require({e.filename for e in entries} == {p.relative_to(payload).as_posix() for p in payload.rglob("*") if p.is_file()}, "ZIP payload inventory mismatch")
        count = manifest(payload)
        result = read_json(payload / "result.json")
        mode = "offline" if role == "offline" else "full"
        require(result["mode"] == mode and result["result"] == "PASS" and result["exit_code"] == 0, "payload did not pass")
        require(result["source_commit"] == head and result["source_tree"] == run["head_commit"]["tree_id"], "payload source mismatch")
        require(result["source_archive_sha256"] == archive_digest, "source archive mismatch")
        context = result["github_actions"]
        expected = {"GITHUB_SERVER_URL": "https://github.com", "GITHUB_REPOSITORY": run["repository"]["full_name"],
                    "GITHUB_RUN_ID": str(run["id"]), "GITHUB_RUN_ATTEMPT": str(run["run_attempt"]),
                    "GITHUB_JOB": role, "GITHUB_SHA": head, "GITHUB_EVENT_NAME": run["event"]}
        require(context == expected, "Actions context mismatch")
        steps = ["compiler", "install-sdk"]
        if mode == "full":
            steps += ["create-venv", "install-oracles", "install-xport", "oracle-versions", "fetch-corpus"]
        steps += ["checks"]
        require([s["name"] for s in result["steps"]] == steps, "missing verification steps")
        require(all(s["result"] == "PASS" and s["exit_code"] == 0 for s in result["steps"]), "verification step failed")
        require(result["fresh_sdk"] and not result["build_cache_reused"], "SDK/cache boundary mismatch")
        require(result["fresh_oracles"] == (mode == "full") and result["fresh_corpus"] == (mode == "full"), "oracle/corpus boundary mismatch")
        for snapshot in (payload / "inputs").iterdir():
            path = "tests/corpus.json" if snapshot.name == "corpus.json" else "tools/" + snapshot.name
            require(snapshot.read_bytes() == git("show", head + ":" + path), "Git/input snapshot mismatch")
        require((payload / "runner.py").read_bytes() == git("show", head + ":tools/verify_release.py"), "runner snapshot mismatch")
        lock = read_json(payload / "inputs/toolchain.json")
        sdk = read_json(payload / "sdk-install.json")
        require(sdk["result"] == "PASS" and sdk["archive_version"] == lock["archive_version"], "SDK identity mismatch")
        require(sdk["native"]["sha256"] == lock["archive_sha256"] and sdk["core"]["sha256"] == lock["core_sha256"], "SDK hash mismatch")
        require(not sdk["existing_sdk_read"] and not sdk["download_cache_reused"] and sdk["bundled_backend"] == "native", "SDK reuse/backend mismatch")
        require(all(value in sdk["version_output"] for value in [lock["moon"], lock["moon_commit"], lock["moonc"]]), "SDK version mismatch")
        log = (payload / "checks.log").read_text()
        require("Total tests: 27, passed: 27, failed: 0." in log, "unit test count mismatch")
        require(log.rstrip().endswith("PASS: all requested checks completed; none skipped"), "checks incomplete")
        for script in ["test_inspect.py", "test_export.py", "test_exchange.py", "test_fixtures.py", "test_malformed.py", "test_consumer.py"]:
            require("/tools/" + script in log, "missing offline integration: " + script)
        corpus = []
        if mode == "full":
            packages = read_json(payload / "oracle-packages.json")
            for line in (payload / "inputs/requirements-oracle.txt").read_text().splitlines():
                if line.strip() and not line.startswith("#"):
                    package, version = line.split("==")
                    require(packages[package] == version, "oracle version mismatch: " + package)
            require(packages["xport"] == "3.6.1", "xport version mismatch")
            require("PASS: xport reads all 4 members; ReadStat reads first; 28 missing byte vectors exact" in log, "missing independent writer checks")
            corpus = [json.loads(line) for line in log.splitlines() if line.startswith('{"member":')]
            expected_members = {item["member"]: item for item in read_json(payload / "inputs/corpus.json")}
            require(len(corpus) == 3 and {item["member"] for item in corpus} == set(expected_members), "corpus inventory mismatch")
            for item in corpus:
                require(item["result"] == "PASS" and item["max_ulp"] == 0 and item["metadata"] == "exact declared attributes", "corpus comparison failed")
                require(item["sha256"] == expected_members[item["member"]]["sha256"], "corpus input hash mismatch")
                require(item["cells"] == item["rows"] * item["columns"], "corpus count mismatch")
            require(sum(item["cells"] for item in corpus) == 620612, "corpus cell total mismatch")
        summaries.append({"job": role, "job_url": job["html_url"], "artifact_id": artifact["id"],
                          "artifact_name": name, "zip_sha256": sha256(data), "manifest_files_verified": count,
                          "result": "PASS", "unit_test_groups": 27, "host": result["host"], "corpus": corpus})
    require({item["job"] for item in summaries} == set(job_map), "missing artifact for a job")
    return {"result": "PASS", "run_id": run["id"], "run_attempt": run["run_attempt"], "run_url": run["html_url"],
            "source_commit": head, "source_archive_sha256": archive_digest, "jobs": summaries,
            "boundary": "archived GitHub API/ZIP manifests/source identities verified locally; no new workflow or product tests executed"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.directory.resolve()), indent=2))
