#!/usr/bin/env bash
# Install into an explicit, new directory; never replace the user's toolchain.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo 'usage: bash tools/install_toolchain.sh NEW_PREFIX' >&2
  exit 2
fi
task_prefix="$(realpath -m "$1")"
if [ -e "$task_prefix" ]; then
  echo 'prefix already exists; choose a new directory' >&2
  exit 2
fi
case "$(uname -ms)" in
  'Linux x86_64') task_target=linux-x86_64 ;;
  *) echo 'only Linux x86_64 is validated' >&2; exit 2 ;;
esac
task_version='0.1.20261012%2B748b63c'
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
# HTTP failures are fatal. No fallback to an unpinned "latest" build.
curl --fail --location --retry 2 --max-time 180 \
  "https://cli.moonbitlang.com/binaries/$task_version/moonbit-$task_target.tar.gz" \
  --output "$task_tmp/moonbit.tar.gz"
curl --fail --location --retry 2 --max-time 180 \
  "https://cli.moonbitlang.com/cores/core-$task_version.tar.gz" \
  --output "$task_tmp/core.tar.gz"
mkdir -p "$task_prefix"
tar xf "$task_tmp/moonbit.tar.gz" -C "$task_prefix"
tar xf "$task_tmp/core.tar.gz" -C "$task_prefix/lib"
chmod +x "$task_prefix"/bin/* "$task_prefix/bin/internal/tcc"
export MOON_HOME="$task_prefix"
export PATH="$task_prefix/bin:$PATH"
moon -C "$task_prefix/lib/core" bundle --warn-list -a --target native
moon version --all
python3 - <<'PY'
import subprocess
version=subprocess.check_output(['moon','version','--all'],text=True)
assert '0.1.20261012' in version and '748b63c' in version and 'v0.10.15+943464bfa' in version,version
PY
