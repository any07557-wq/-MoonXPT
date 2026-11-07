MoonXPT v0.1.0 provides a MoonBit-native streaming SAS XPORT V5 reader/writer and `inspect`, `export`, and `write` CLI commands. CSV with versioned JSON metadata supports explicit round-trip policies. Validated platform: Linux x86_64 native. See the source compatibility documentation for numeric, tail-padding, encoding, and output-recovery limits.

### Source identity and downloads

The annotated `v0.1.0` tag points to **`2cddd31bb8b88648f619969dbb4fe195051735b4`**, the exact source commit of both verified product archives. The subsequent `aa56905542eac189c7d18753444d6eaa97ecf719` commit records Stage B evidence; it is not a different artifact source.

- **`moonxpt-0.1.0.zip`**: filtered library package with its dedicated README, public interfaces, examples, fixtures, licenses, and required user documentation.
- **`moonxpt-0.1.0-source.zip`**: complete tracked source, tools, CI, tests, documentation and licenses, plus `history/moonxpt.bundle` restoring all 29 commits through the source commit.
- **`moonxpt-0.1.0-validation.zip`**: fresh-install validation reports and raw tag-CI API, artifact ZIPs and logs. It contains no SDK, venv, build cache, or raw public corpus.
- `SHA256SUMS`, `release-manifest.json` and the two inventory JSON files identify the original product archives. GitHub's automatic source downloads are separate and do not include the supplementary Git bundle.

```text
93df9b777bdb075dab1213fdf71fdef3fc09b515dd1676b3d635d8205d9962f1  moonxpt-0.1.0.zip
853064a112ad766635fc8521c18a2c5993fc09c7697cfb191a2523371e911b13  moonxpt-0.1.0-source.zip
```

The exact retained ZIPs were validated. Recompressing the Git bundle can change source-ZIP bytes while restoring identical Git source and history; byte-identical repacking is not promised.

### Validation

- Stage B extracted-archive validation: newly downloaded pinned official SDK/core, newly installed pinned Python oracles and newly downloaded SHA-256-checked corpus in an isolated user space; no developer SDK, oracle environment or build cache reused. The host kernel/base OS was shared.
- [Main push CI #42361511304](https://github.com/any07557-wq/-MoonXPT/actions/runs/42361511304): offline job passed; public corpus is intentionally opt-in.
- [Exact-tag full CI #42361761773](https://github.com/any07557-wq/-MoonXPT/actions/runs/42361761773): offline and public-corpus jobs passed. Both downloaded artifacts were verified against GitHub SHA-256, complete package manifests, pinned inputs, and the tagged Git source.
- 27/27 test groups, six offline integration entry points, two independent oracle families, and 620,612 real-data cells with declared metadata passed; maximum observed difference was 0 ULP. The three NHANES files contain numeric columns; character encodings, multi-member data and special missing values use independent fixtures and byte vectors. No new cloud benchmark is claimed.

### Publication boundaries

This GitHub Release does **not** publish to Mooncakes or submit a contest entry. The immutable v0.1.0 archives retain module name `any07557/moonxpt`. The user selected **`any07557-wq/moonxpt`** for a later, separately reviewed Mooncakes namespace migration; registry installation of this new name/version is not claimed.

MIT license for project-owned code; retain `THIRD_PARTY.md`, runtime/toolchain notices and fixture source records. Raw NHANES data and oracle dependencies are not distributed in the product archives.
