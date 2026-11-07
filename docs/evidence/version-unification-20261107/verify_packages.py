"""Stage A candidate ZIP version inspection and extracted release-build checks."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import zipfile

ROOT = Path.cwd()
OUT = Path(__file__).resolve().parent
COMMIT = "f1230b64e991ad94ba5455483665c6c4c387f77e"
VERSION = "0.1.0"
report = {"source_commit": COMMIT, "product_version": VERSION, "result": "FAIL",
          "started_utc": datetime.now(timezone.utc).isoformat(), "artifacts": [],
          "scope": "stage A version candidates; not final Release artifacts",
          "toolchain": "existing fixed local SDK; not independent installation or a new cloud run"}


def run(command, cwd, log):
    command = list(map(str, command))
    print("+", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (OUT / log).write_bytes(result.stdout)
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, command)
    return result.stdout


def extract(archive, target):
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.namelist():
            assert not Path(member).is_absolute() and ".." not in Path(member).parts
        bundle.extractall(target)


try:
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() == COMMIT
    artifacts = OUT / "artifacts"
    artifacts.mkdir(exist_ok=False)
    source_zip = artifacts / f"moonxpt-{VERSION}-source.zip"
    run(["git", "archive", "--format=zip", "--output=" + str(source_zip), COMMIT], ROOT, "source-archive.log")
    with tempfile.TemporaryDirectory(prefix="moonxpt-version-") as temporary:
        work = Path(temporary)
        source = work / "source"
        extract(source_zip, source)
        run(["moon", "package", "--target-dir", work / "package-build"], source, "library-package.log")
        library_zip = artifacts / f"moonxpt-{VERSION}.zip"
        shutil.copyfile(work / f"package-build/publish/any07557-moonxpt-{VERSION}.zip", library_zip)
        for role, archive in [("library", library_zip), ("source", source_zip)]:
            target = work / (role + "-extracted")
            extract(archive, target)
            module = tomllib.loads((target / "moon.mod").read_text())
            assert module["version"] == VERSION
            assert "MoonXPT " + VERSION + " — SAS XPORT V5 (native)" in (target / "cmd/moonxpt/main.mbt").read_text()
            assert "**" + VERSION + "**" in (target / "README.md").read_text()
            assert "## " + VERSION + "（待发布）" in (target / "CHANGELOG.md").read_text()
            assert "**" + VERSION + "**" in (target / "docs/compatibility.md").read_text()
            assert "any07557/moonxpt@" + VERSION in (target / "docs/reproduction.md").read_text()
            assert (target / "tools").exists() == (role == "source")
            assert (target / ".github/workflows/ci.yml").exists() == (role == "source")
            assert all(not (target / p).exists() for p in [".git", ".cache", "_build"])
            run(["moon", "build", "--target", "native", "--release", "--deny-warn"], target, role + "-build.log")
            exe = target / "_build/native/release/build/cmd/moonxpt/moonxpt.exe"
            help_text = run([exe, "--help"], target, role + "-help.txt").decode()
            banner = help_text.splitlines()[0]
            assert banner == f"MoonXPT {VERSION} — SAS XPORT V5 (native)"
            inspect = run([exe, "inspect", "tests/fixtures/readstat-v5.xpt", "--json", "--count-rows", "--rows", "ORACLE=4"], target, role + "-inspect.json")
            assert json.loads(inspect)["members"][0]["row_count"] == 4
            with zipfile.ZipFile(archive) as bundle:
                inventory = [{"file": x.filename, "bytes": x.file_size,
                              "sha256": hashlib.sha256(bundle.read(x)).hexdigest()}
                             for x in bundle.infolist() if not x.is_dir()]
            (OUT / (role + "-inventory.json")).write_text(json.dumps({"files": inventory}, indent=2) + "\n")
            report["artifacts"].append({"role": role, "file": "artifacts/" + archive.name,
                "bytes": archive.stat().st_size, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                "module_version": module["version"], "cli_banner": banner,
                "files": len(inventory), "result": "PASS", "extracted_release_build": "PASS",
                "fixture_inspect_rows": 4, "inventory": role + "-inventory.json"})
    report["result"] = "PASS"
finally:
    report["completed_utc"] = datetime.now(timezone.utc).isoformat()
    (OUT / "version-report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2), flush=True)
