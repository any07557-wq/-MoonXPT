# MoonXPT exchange schema version 1

Each selected member exports one UTF-8 CSV and one JSON object. `schema_version`
is integer 1; unknown versions fail. JSON records target `encoding`, `library`,
`dataset`, and `csv` conventions. Dataset has name, label, type, producer/time
fields, row width, descriptor size, and ordered `variables` containing name,
label, type (`numeric`/`character`), storage width, offset, number, hash,
format and informat (name, width, decimals, justification). Original fixed
metadata fields are also representable as byte arrays, avoiding text guessing.
No per-cell data belongs in JSON. Export records observed `row_count` after
streaming, to resolve V5 tail ambiguity during reconstruction/verification.

CSV has a required header matching variable order, comma delimiter, double quote
escaping, LF output records, no BOM. Import accepts CRLF or LF, quoted CR/LF,
commas and doubled quotes; rejects malformed quoting, BOM and non-UTF-8.
Empty string and leading/trailing spaces are retained; no implicit trim.
Stored character fields include padding spaces in CSV by default; the original
un-padded length is unknowable from XPT. Encoded byte length must fit width.

Numeric missing tokens are `.`, `._`, `.A`–`.Z`. Character `.A` stays literal.
Finite numbers use locale-independent shortest round-trip Double decimal.
Blank numeric fields fail unless an explicit import option enables missing.
NaN and infinity always fail; missing must use the explicit tokens.
Duplicates, inconsistent counts/types, overlapping positions, unknown versions
and inconsistent CSV contract fail. Limits also apply to metadata and CSV rows.

Writer emits V5 140-byte descriptors, reconstructs normalized header padding and
reserved fields, and uses supplied timestamps (default 01JAN00:00:00:00).
It does not execute SAS formats, reinterpret dates, infer encoding or invent
external value labels. Numeric semantics and raw-field access are separate from
whole-file byte identity.
