#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target native --release --deny-warn
xpt_cli="$PWD/_build/native/release/build/cmd/moonxpt/moonxpt.exe"
xpt_source=tests/fixtures/readstat-v5.xpt
xpt_member=ORACLE
xpt_rows=4
xpt_encoding=ascii
if [ "${1:-}" = --real ]; then
  python3 tools/fetch_corpus.py
  xpt_source=.cache/corpus/DEMO_J.xpt
  xpt_member=DEMO_J
  xpt_rows=9254
  xpt_encoding=windows-1252
elif [ "$#" -gt 0 ]; then
  echo 'usage: bash tools/demo.sh [--real]' >&2
  exit 2
fi
mkdir -p .cache
xpt_demo_dir="$(mktemp -d "$PWD/.cache/demo-XXXXXX")"
"$xpt_cli" inspect "$xpt_source" --json --count-rows --encoding "$xpt_encoding" --rows "$xpt_member=$xpt_rows"
"$xpt_cli" export "$xpt_source" --member "$xpt_member" --rows "$xpt_member=$xpt_rows" \
  --encoding "$xpt_encoding" --csv "$xpt_demo_dir/data.csv" --metadata "$xpt_demo_dir/data.meta.json"
"$xpt_cli" write "$xpt_demo_dir/data.csv" --metadata "$xpt_demo_dir/data.meta.json" --output "$xpt_demo_dir/restored.xpt"
"$xpt_cli" inspect "$xpt_demo_dir/restored.xpt" --json --count-rows --encoding "$xpt_encoding" --rows "$xpt_member=$xpt_rows"
printf 'Artifacts: %s\n' "$xpt_demo_dir"
