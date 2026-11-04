# Public contracts and layering

The core package holds L0 models, L1 codecs and L2 reader/writer in separate
source files. `exchange/` is L3 and `cmd/moonxpt/` is L4. No core import of
filesystem, CSV, Python or R is allowed. Metadata byte fields are exact fixed
storage fields on input; text presentation removes only header padding.

Input callbacks return at most the requested bytes, permit short reads, and
return empty only at permanent EOF. Input::exact loops, counts physical offsets
and reports partial reads. Row consumption is pull-based; stopping calls stops
I/O. Caller owns closing its source. Sink callbacks consume the complete chunk
or raise. Once failed, Output is poisoned. Writers must require finish; platform
adapters stage incomplete output, never promote it on failure.

Default limits: 9999 columns, 16 MiB row, 1024 members, 1 billion rows/member,
1 TiB input. Bounds are checked before relevant allocation; signed negative
or overflowing fields fail. Offsets/row counters are Int64; unavailable context
is null. Underlying I/O errors propagate; CLI normalizes diagnostics.

V5 stores no observation count. Strict reading rejects multiple valid row/padding
interpretations; per-member row hints resolve them. TrimPadding is an explicit
compatibility option. Member candidates are tested only on physical boundaries
with descriptor validation; data matching a valid member structure is itself
ambiguous and requires a row hint. Never scan the entire file for a marker.

IBM values retain raw row bytes; Double is the semantic view (56-bit IBM fraction
is truncated toward zero to 53-bit IEEE, with error strictly below 1 ULP; see adr-002-numeric.md). Encoding is explicit. No implicit date or
value-label conversions. Writer normalizes reserved header bytes and 140-byte
descriptors; semantic CSV round trips do not promise original file hashes.
