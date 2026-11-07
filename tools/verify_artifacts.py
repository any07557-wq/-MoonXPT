"""Validate final ZIPs, then test their extracted contents in fresh bubblewrap userspace."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def now():
    return datetime.now(timezone.utc).isoformat()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text())


def inner():
    work, evidence = Path("/work"), Path("/evidence")
    source, library = work / "source", work / "library"
    report = {"result": "FAIL", "started_utc": now(), "steps": [],
              "fresh_sdk": False, "fresh_oracles": False, "fresh_corpus": False,
              "environment": "same-host bubblewrap userspace; shared base OS/kernel; developer HOME hidden",
              "host": {"kernel": platform.release(), "python": sys.version},
              "source_commit": read(source / "ARTIFACT.json")["source_commit"]}

    def run(name, command, cwd=source):
        command = list(map(str, command))
        step = {"name": name, "command": command, "result": "FAIL", "started_utc": now()}
        report["steps"].append(step)
        print("+ " + " ".join(command), flush=True)
        try:
            with (evidence / (name + ".log")).open("w") as log:
                with subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                      text=True, errors="replace") as process:
                    for line in process.stdout:
                        log.write(line); log.flush(); print(line, end="", flush=True)
                    step["exit_code"] = process.wait()
            require(step["exit_code"] == 0, "step failed: " + name)
            step["result"] = "PASS"
        finally:
            step["completed_utc"] = now()

    try:
        require(not Path("/home/user/.moon").exists() and not Path("/home/user/MoonBit_Program").exists(), "developer environment visible")
        require(not any(importlib.util.find_spec(x) for x in ["pyreadstat", "xport", "pandas", "numpy"]), "existing oracle visible")
        require(sys.version_info[:3] == (3, 14, 4), "full artifact validation requires Python 3.14.4")
        require(all(not (root / name).exists() for root in [source, library] for name in ["_build", ".cache"]), "build/dependency cache copied")
        report["precheck"] = "PASS: hidden developer HOME, no oracle modules or source build caches"
        recovered = work / "recovered-history"
        run("history-clone", ["git", "clone", "--quiet", source / "history/moonxpt.bundle", recovered])
        run("history-bundle", ["git", "bundle", "verify", source / "history/moonxpt.bundle"], recovered)
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=recovered, text=True).strip()
        require(commit == report["source_commit"], "history HEAD mismatch")
        count = int(subprocess.check_output(["git", "rev-list", "--count", "HEAD"], cwd=recovered))
        require(count == read(source / "ARTIFACT.json")["source_commit_count"], "history count mismatch")
        run("history-frozen-base", ["git", "merge-base", "--is-ancestor", "1516dfd033d4ecee1bf0fd5cb35c9ec77762a774", "HEAD"], recovered)
        names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", "-z", "HEAD"], cwd=recovered).decode().split("\0")
        for name in filter(None, names):
            require((source / name).read_bytes() == subprocess.check_output(["git", "show", "HEAD:" + name], cwd=recovered), "source/history content mismatch: " + name)
        report["history"] = {"result": "PASS", "head": commit, "commits": count, "all_tracked_files_match": True}
        run("install-sdk", [sys.executable, source / "tools/install_toolchain.py", work / "sdk", "--receipt", evidence / "sdk-install.json"])
        report["fresh_sdk"] = True
        os.environ["MOON_HOME"] = str(work / "sdk")
        os.environ["PATH"] = str(work / "sdk/bin") + ":/usr/bin:/bin"
        run("create-venv", [sys.executable, "-m", "venv", source / ".cache/venv"])
        python = source / ".cache/venv/bin/python"
        pip = [python, "-m", "pip", "--isolated", "install", "--no-cache-dir", "--index-url", "https://pypi.org/simple"]
        run("install-oracles", pip + ["-r", source / "tools/requirements-oracle.txt"])
        run("install-xport", pip + ["--no-deps", "xport==3.6.1"])
        code = ("import json,sys;from importlib.metadata import distributions;from pathlib import Path;"
                "Path(sys.argv[1]).write_text(json.dumps({d.metadata['Name']:d.version for d in distributions()},indent=2)+'\\n')")
        run("oracle-versions", [python, "-c", code, evidence / "oracle-packages.json"])
        report["fresh_oracles"] = True
        run("fetch-corpus", [python, source / "tools/fetch_corpus.py"])
        report["fresh_corpus"] = True
        run("source-checks", [python, source / "tools/check.py", "--oracle", "--corpus"])
        source_log = (evidence / "source-checks.log").read_text()
        require("Total tests: 27, passed: 27, failed: 0." in source_log and source_log.rstrip().endswith("PASS: all requested checks completed; none skipped"), "source checks incomplete")
        cells = [json.loads(line) for line in source_log.splitlines() if line.startswith('{"member":')]
        require(len(cells) == 3 and sum(x["cells"] for x in cells) == 620612 and all(x["result"] == "PASS" and x["max_ulp"] == 0 for x in cells), "corpus comparison incomplete")
        report["source"] = {"result": "PASS", "test_groups": 27, "corpus": cells}
        for name, command in [("library-check", ["moon", "check", "--target", "native", "--deny-warn"]),
                              ("library-tests", ["moon", "test", "--target", "native", "--deny-warn"]),
                              ("library-build", ["moon", "build", "--target", "native", "--release", "--deny-warn"])]:
            run(name, command, library)
        require("Total tests: 27, passed: 27, failed: 0." in (evidence / "library-tests.log").read_text(), "library tests incomplete")
        exe = library / "_build/native/release/build/cmd/moonxpt/moonxpt.exe"
        run("library-help", [exe, "--help"], library)
        require((evidence / "library-help.log").read_text().splitlines()[0] == "MoonXPT 0.1.0 — SAS XPORT V5 (native)", "library CLI version mismatch")
        fixture = library / "tests/fixtures/readstat-v5.xpt"
        csv, metadata, rebuilt = work / "table.csv", work / "table.json", work / "rebuilt.xpt"
        run("library-inspect", [exe, "inspect", fixture, "--json", "--count-rows", "--rows", "ORACLE=4"], library)
        run("library-export", [exe, "export", fixture, "--member", "ORACLE", "--rows", "ORACLE=4", "--csv", csv, "--metadata", metadata], library)
        run("library-write", [exe, "write", csv, "--metadata", metadata, "--output", rebuilt], library)
        run("library-reinspect", [exe, "inspect", rebuilt, "--json", "--count-rows", "--rows", "ORACLE=4"], library)
        require(read(evidence / "library-reinspect.log")["members"][0]["row_count"] == 4, "library roundtrip count mismatch")
        run("library-consumer", [sys.executable, source / "tools/test_consumer.py", "--library-dir", library], work)
        report["library"] = {"result": "PASS", "test_groups": 27, "cli_roundtrip_rows": 4, "public_consumer": "PASS", "oracle_runtime_required": False}
        report["result"] = "PASS"
    except BaseException as error:
        report["error"] = str(error)
        print("FAIL:", error, flush=True)
    finally:
        report["completed_utc"] = now()
        (evidence / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["result"] == "PASS" else 1


def outer(directory, destination):
    destination.mkdir(parents=True, exist_ok=False)
    work, evidence = destination / "work", destination / "evidence"
    work.mkdir(); evidence.mkdir()
    build = read(directory / "release-manifest.json")
    require(build["result"] == "PASS" and {a["kind"] for a in build["artifacts"]} == {"source", "library"}, "artifact build incomplete")
    audit = {"source_commit": build["source_commit"], "result": "FAIL", "artifacts": []}
    for artifact in build["artifacts"]:
        path = directory / artifact["file"]
        require(path.stat().st_size == artifact["bytes"] and sha(path.read_bytes()) == artifact["sha256"], "artifact ZIP checksum mismatch")
        target = work / artifact["kind"]
        target.mkdir()
        with zipfile.ZipFile(path) as bundle:
            entries = bundle.infolist()
            require(len(entries) < 5000 and sum(e.file_size for e in entries) < 100 * 1024 * 1024, "ZIP resource limit")
            require(len(entries) == len({e.filename for e in entries}), "duplicate ZIP entry")
            for entry in entries:
                name = PurePosixPath(entry.filename)
                require(not name.is_absolute() and ".." not in name.parts and "\\" not in entry.filename, "unsafe ZIP path")
                require((entry.external_attr >> 16) & 0o170000 != 0o120000, "ZIP symlink")
            bundle.extractall(target)
        metadata = read(target / "ARTIFACT.json")
        require(metadata["source_commit"] == build["source_commit"] and metadata["kind"] == artifact["kind"], "artifact identity mismatch")
        records = read(target / "PACKAGE-MANIFEST.json")["files"]
        require(len(records) == len({r["file"] for r in records}), "duplicate manifest entry")
        require({r["file"] for r in records} | {"PACKAGE-MANIFEST.json"} == {e.filename for e in entries}, "manifest inventory mismatch")
        for record in records:
            data = (target / record["file"]).read_bytes()
            require(len(data) == record["bytes"] and sha(data) == record["sha256"], "payload manifest mismatch")
        license_hashes = {}
        for name in artifact["license_files"]:
            data = (target / name).read_bytes()
            expected = subprocess.check_output(["git", "show", build["source_commit"] + ":" + name], cwd=ROOT)
            require(data == expected, "license/provenance differs from source commit")
            license_hashes[name] = sha(data)
        for item in read(target / "tests/fixtures/manifest.json"):
            require(sha((target / "tests/fixtures" / item["file"]).read_bytes()) == item["sha256"], "fixture provenance mismatch")
        audit["artifacts"].append({"kind": artifact["kind"], "zip_sha256": artifact["sha256"], "manifest_files_verified": len(records), "license_files": license_hashes, "fixture_hashes": "PASS"})
    require((work / "source/tools/verify_artifacts.py").read_bytes() == Path(__file__).read_bytes(), "verifier must match selected committed source")
    audit["result"] = "PASS"
    (evidence / "integrity-and-licenses.json").write_text(json.dumps(audit, indent=2) + "\n")
    command = ["bwrap", "--unshare-user", "--unshare-pid", "--clearenv",
        "--ro-bind", "/usr", "/usr", "--ro-bind", "/lib", "/lib", "--ro-bind", "/lib64", "/lib64",
        "--ro-bind", "/bin", "/bin", "--ro-bind", "/etc", "/etc", "--proc", "/proc", "--dev", "/dev",
        "--tmpfs", "/home", "--dir", "/home/user", "--tmpfs", "/tmp",
        "--bind", str(work), "/work", "--bind", str(evidence), "/evidence",
        "--setenv", "PATH", "/usr/bin:/bin", "--setenv", "LANG", "C.UTF-8",
        "--setenv", "PYTHONNOUSERSITE", "1", "--setenv", "PIP_CONFIG_FILE", "/dev/null"]
    resolver = Path("/etc/resolv.conf").resolve()
    if resolver.parent != Path("/etc"):
        command += ["--dir", str(resolver.parent), "--ro-bind", str(resolver), str(resolver)]
    for key in ["HTTPS_PROXY", "HTTP_PROXY", "https_proxy", "http_proxy", "NO_PROXY", "no_proxy"]:
        if key in os.environ:
            command += ["--setenv", key, os.environ[key]]
    command += ["--chdir", "/work/source", "/usr/bin/python3", "/work/source/tools/verify_artifacts.py", "--inside"]
    with (evidence / "console.log").open("w") as log:
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
            for line in process.stdout:
                log.write(line); log.flush(); print(line, end="", flush=True)
            code = process.wait()
    (evidence / "process.json").write_text(json.dumps({"exit_code": code, "result": "PASS" if code == 0 else "FAIL", "developer_home_mounted": False, "shared_host_os_kernel": True}, indent=2) + "\n")
    print("Evidence:", evidence, flush=True)
    return code


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path)
    parser.add_argument("--evidence-dir", type=Path)
    parser.add_argument("--inside", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.inside:
        raise SystemExit(inner())
    require(args.directory is not None and args.evidence_dir is not None, "directory and --evidence-dir required")
    raise SystemExit(outer(args.directory.resolve(), args.evidence_dir.resolve()))
