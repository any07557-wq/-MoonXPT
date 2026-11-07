"""Build distinct library/source ZIPs from one committed tree, without publishing."""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tempfile
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LICENSES = ["LICENSE", "THIRD_PARTY.md", "licenses/MoonBit-core-Apache-2.0.txt",
            "licenses/MoonBit-core-NOTICE.txt", "licenses/MoonBit-toolchain-CREDITS.md",
            "tests/fixtures/manifest.json"]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(*args, cwd=ROOT):
    return subprocess.check_output(["git", *map(str, args)], cwd=cwd)


def inventory(files):
    return [{"file": name, "bytes": len(data), "sha256": digest(data)}
            for name, (data, mode) in sorted(files.items())]


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode()


def validate_links(files):
    for name, (data, _) in files.items():
        if not name.endswith(".md"):
            continue
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", data.decode()):
            if "://" in target or target.startswith("#"):
                continue
            target = target.split("#")[0]
            require(not target.startswith("/"), "absolute local link in library: " + name)
            path = PurePosixPath(name).parent / target
            require(path.as_posix() in files, f"missing library link: {name} -> {target}")


def write_zip(path, files, timestamp):
    stamp = datetime.fromtimestamp(timestamp, timezone.utc).timetuple()[:6]
    with zipfile.ZipFile(path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for name, (data, mode) in sorted(files.items()):
            entry = zipfile.ZipInfo(name, stamp)
            entry.create_system = 3
            entry.external_attr = (0o100000 | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(entry, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commit", default="HEAD")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    commit = git("rev-parse", args.commit + "^{commit}").decode().strip()
    require(git("show", commit + ":tools/build_artifacts.py") == Path(__file__).read_bytes(),
            "builder must match the selected committed source")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    archive = git("archive", commit)
    tree = git("rev-parse", commit + "^{tree}").decode().strip()
    timestamp = int(git("show", "-s", "--format=%ct", commit))
    count = int(git("rev-list", "--count", commit))
    report = {"source_commit": commit, "source_tree": tree, "source_archive_sha256": digest(archive),
              "source_commit_count": count, "builder_sha256": digest(Path(__file__).read_bytes()),
              "result": "FAIL", "artifacts": []}
    try:
        with tempfile.TemporaryDirectory(prefix="moonxpt-package-") as temporary:
            work = Path(temporary)
            source = work / "source"
            source.mkdir()
            source_files = {}
            with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                for member in bundle.getmembers():
                    require(member.isdir() or member.isfile(), "non-regular Git archive entry")
                    if member.isfile():
                        source_files[member.name] = (bundle.extractfile(member).read(), member.mode)
                bundle.extractall(source, filter="data")
            module = tomllib.loads((source / "moon.mod").read_text())
            version = module["version"]
            require(module["readme"] == "README.library.md", "unexpected library README")
            require(module["repository"] == "https://github.com/any07557-wq/-MoonXPT", "repository metadata mismatch")
            with (output / "moon-package.log").open("wb") as log:
                subprocess.run(["moon", "package", "--target-dir", str(work / "build")], cwd=source,
                               stdout=log, stderr=subprocess.STDOUT, check=True)
            packed = work / f"build/publish/{module['name'].replace('/', '-')}-{version}.zip"
            with zipfile.ZipFile(packed) as bundle:
                library_files = {entry.filename: (bundle.read(entry), (entry.external_attr >> 16) & 0o777 or 0o644)
                                 for entry in bundle.infolist() if not entry.is_dir()}
            require("README.md" not in library_files and "README.library.md" in library_files, "library README filtering failed")
            require(not any(n.startswith(("tools/", ".github/", "docs/evidence/", "history/")) for n in library_files), "developer files in library")
            validate_links(library_files)
            for name, (data, _) in library_files.items():
                require(name in source_files and source_files[name][0] == data, "library content differs from committed source: " + name)
            for name in ["tools/verify_artifacts.py", ".github/workflows/ci.yml", "docs/progress.md", "README.md"]:
                require(name in source_files, "full source file missing: " + name)
            for files in [source_files, library_files]:
                for name in files:
                    require(not set(PurePosixPath(name).parts) & {".git", ".cache", "_build", "dist", "__pycache__"}, "cache or private Git directory in payload")
                for name in LICENSES:
                    require(name in files and files[name][0] == source_files[name][0], "license/provenance missing or changed: " + name)
            history = work / "history.git"
            git("init", "--bare", "--quiet", history)
            git("fetch", "--quiet", "--no-tags", ROOT, commit + ":refs/heads/main", cwd=history)
            git("symbolic-ref", "HEAD", "refs/heads/main", cwd=history)
            bundle_path = work / "moonxpt.bundle"
            git("-c", "pack.threads=1", "bundle", "create", bundle_path, "HEAD", "refs/heads/main", cwd=history)
            git("bundle", "verify", bundle_path, cwd=history)
            history_data = bundle_path.read_bytes()
            source_files["history/moonxpt.bundle"] = (history_data, 0o644)
            source_files["history/README.md"] = ((
                "# Complete history through the selected source commit\n\n"
                "From the extracted source root:\n\n```sh\ngit clone history/moonxpt.bundle MoonXPT-history\n"
                "git -C MoonXPT-history rev-parse HEAD\ngit -C MoonXPT-history log --oneline\n```\n\n"
                f"Expected HEAD: `{commit}`. Reachable commits: {count}.\n"
                "This bundle contains committed objects and refs, not local credentials/configuration or build caches.\n"
            ).encode(), 0o644)
            for role, files, filename in [("library", library_files, f"moonxpt-{version}.zip"),
                                          ("source", source_files, f"moonxpt-{version}-source.zip")]:
                metadata = {"schema_version": 1, "kind": role, "module": module["name"], "version": version,
                            "source_commit": commit, "source_tree": tree, "source_commit_count": count,
                            "source_archive_sha256": digest(archive), "readme": module["readme"],
                            "git_history": {"file": "history/moonxpt.bundle", "sha256": digest(history_data),
                                            "complete_through_source_commit": True} if role == "source" else None}
                files["ARTIFACT.json"] = (json_bytes(metadata), 0o644)
                files["PACKAGE-MANIFEST.json"] = (json_bytes({"files": inventory(files)}), 0o644)
                target = output / filename
                write_zip(target, files, timestamp)
                all_files = inventory(files)
                (output / (role + "-inventory.json")).write_bytes(json_bytes({"files": all_files}))
                report["artifacts"].append({"kind": role, "file": filename, "bytes": target.stat().st_size,
                    "sha256": digest(target.read_bytes()), "files": len(files),
                    "inventory": role + "-inventory.json", "license_files": LICENSES})
            report.update(result="PASS", version=version, module=module["name"],
                          history_bundle_sha256=digest(history_data), license_bytes_match_git=True)
            (output / "SHA256SUMS").write_text("".join(f"{a['sha256']}  {a['file']}\n" for a in report["artifacts"]))
    finally:
        (output / "release-manifest.json").write_bytes(json_bytes(report))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
