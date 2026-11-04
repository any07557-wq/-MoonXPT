# ADR 001: native backend and platform boundary

2026-11-04. Use MoonBit native with a C compiler. The installed 20261012
toolchain supports `moon.mod`, `moon.pkg`, `extern "C"` and native-stub.
No external Mooncakes dependency is required. C handles binary file I/O,
exclusive temporary files, renaming, diagnostics and exit status only.
Binary interpretation, text encodings, CSV and JSON remain MoonBit.

Build/test on Linux first; other platforms are unverified until exercised.
The pure core has no filesystem imports. Oracle programs are developer-only.
