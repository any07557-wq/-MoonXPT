"""Fresh SDK/source/oracle verification for CI or a separate Linux host.

Only the committed Git tree is tested. This runner does not create a VM or hide
the host filesystem; its report records the host and optional Actions context.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import traceback

ROOT = Path(__file__).resolve().parents[1]


def now():
    return datetime.now(timezone.utc).isoformat()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_step(report, evidence, name, command, cwd, env):
    command = list(map(str, command))
    step = {"name": name, "command": command, "started_utc": now(),
            "result": "FAIL", "exit_code": None, "log": name + ".log"}
    report["steps"].append(step)
    print("+ " + " ".join(command), flush=True)
    try:
        with (evidence / step["log"]).open("w") as log:
            with subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, errors="replace") as process:
                try:
                    for line in process.stdout:
                        log.write(line)
                        log.flush()
                        print(line, end="", flush=True)
                    step["exit_code"] = process.wait()
                except BaseException:
                    process.terminate()
                    process.wait()
                    raise
        if step["exit_code"]:
            raise subprocess.CalledProcessError(step["exit_code"], command)
        step["result"] = "PASS"
    finally:
        step["completed_utc"] = now()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["offline", "full"], required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True,
                        help="new directory for logs/receipts; never overwritten")
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    report = {"schema_version": 1, "mode": args.mode, "result": "FAIL", "exit_code": 1,
              "started_utc": now(), "steps": [], "source_commit": None,
              "host": {"system": platform.system(), "architecture": platform.machine(),
                       "kernel": platform.release(), "python": sys.version},
              "fresh_sdk": False, "fresh_oracles": False, "fresh_corpus": False,
              "build_cache_reused": False, "source": "git archive of committed HEAD",
              "isolation": "new temporary directories; host filesystem/kernel remain visible",
              "github_actions": None}
    if os.environ.get("GITHUB_ACTIONS") == "true":
        # This is selected run metadata, never a dump of the environment/token.
        report["github_actions"] = {key: os.environ.get(key) for key in [
            "GITHUB_SERVER_URL", "GITHUB_REPOSITORY", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT",
            "GITHUB_JOB", "GITHUB_EVENT_NAME", "GITHUB_SHA"]}
    try:
        if platform.system() != "Linux" or platform.machine() != "x86_64":
            raise ValueError("only Linux x86_64 is validated")
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["source_commit"] = head
        report["source_tree"] = subprocess.check_output(
            ["git", "rev-parse", head + "^{tree}"], cwd=ROOT, text=True).strip()
        archive = subprocess.check_output(["git", "archive", head], cwd=ROOT)
        report["source_archive_sha256"] = hashlib.sha256(archive).hexdigest()
        (evidence / "runner.py").write_bytes(Path(__file__).read_bytes())
        if Path("/etc/os-release").exists():
            shutil.copyfile("/etc/os-release", evidence / "os-release.txt")
        with tempfile.TemporaryDirectory(prefix="moonxpt-verify-") as temporary:
            work = Path(temporary)
            source = work / "source"
            source.mkdir()
            with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                bundle.extractall(source, filter="data")
            if (source / ".cache").exists() or (source / "_build").exists():
                raise ValueError("committed archive contains build/cache directories")
            if not (source / "tools/verify_release.py").exists() or (
                    source / "tools/verify_release.py").read_bytes() != Path(__file__).read_bytes():
                raise ValueError("commit the verification runner before testing its committed tree")
            inputs = evidence / "inputs"
            inputs.mkdir()
            for name in ["toolchain.json", "requirements-oracle.txt", "install_toolchain.py",
                         "install_toolchain.sh", "check.py"]:
                shutil.copyfile(source / "tools" / name, inputs / name)
            shutil.copyfile(source / "tests/corpus.json", inputs / "corpus.json")
            env = dict(os.environ, PYTHONNOUSERSITE="1", PIP_CONFIG_FILE="/dev/null")
            env.pop("MOON_HOME", None)
            run_step(report, evidence, "compiler", ["cc", "--version"], source, env)
            sdk = work / "sdk"
            run_step(report, evidence, "install-sdk", [sys.executable,
                     source / "tools/install_toolchain.py", sdk,
                     "--receipt", evidence / "sdk-install.json"], source, env)
            report["fresh_sdk"] = True
            env.update(MOON_HOME=str(sdk), PATH=str(sdk / "bin") + os.pathsep + env.get("PATH", "/usr/bin:/bin"))
            python = Path(sys.executable)
            if args.mode == "full":
                venv = source / ".cache/venv"
                run_step(report, evidence, "create-venv", [python, "-m", "venv", venv], source, env)
                python = venv / "bin/python"
                pip = [python, "-m", "pip", "--isolated", "install", "--no-cache-dir",
                       "--index-url", "https://pypi.org/simple"]
                run_step(report, evidence, "install-oracles", pip + ["-r", source / "tools/requirements-oracle.txt"], source, env)
                run_step(report, evidence, "install-xport", pip + ["--no-deps", "xport==3.6.1"], source, env)
                code = ("import json,sys; from importlib.metadata import distributions; "
                        "from pathlib import Path; Path(sys.argv[1]).write_text("
                        "json.dumps({d.metadata['Name']:d.version for d in distributions()},indent=2)+'\\n')")
                run_step(report, evidence, "oracle-versions", [python, "-c", code,
                         evidence / "oracle-packages.json"], source, env)
                report["fresh_oracles"] = True
                run_step(report, evidence, "fetch-corpus", [python, source / "tools/fetch_corpus.py"], source, env)
                report["fresh_corpus"] = True
            command = [python, source / "tools/check.py"]
            if args.mode == "full":
                command += ["--oracle", "--corpus"]
            run_step(report, evidence, "checks", command, source, env)
        report.update(result="PASS", exit_code=0)
    except BaseException as error:
        report["error"] = str(error)
        if isinstance(error, subprocess.CalledProcessError):
            report["exit_code"] = error.returncode if error.returncode > 0 else 1
        (evidence / "failure.log").write_text(traceback.format_exc())
        print("FAIL:", error, file=sys.stderr, flush=True)
    finally:
        report["completed_utc"] = now()
        (evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        files = [{"file": str(p.relative_to(evidence)), "bytes": p.stat().st_size, "sha256": digest(p)}
                 for p in sorted(evidence.rglob("*")) if p.is_file()]
        (evidence / "manifest.json").write_text(json.dumps({"files": files}, indent=2) + "\n")
    print("Evidence:", evidence, "result:", report["result"], flush=True)
    return report["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
