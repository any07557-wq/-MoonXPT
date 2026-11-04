# Compatibility evidence (milestone S1)

| Capability | Status | Evidence/remaining work |
|---|---|---|
| Native backend | verified | moon check/test/build/run; 20261012 Linux |
| Models, diagnostics, short-read I/O | implemented/tested | model_test.mbt |
| V5 headers/136,140 descriptors | not implemented | S2 |
| IBM numeric, 28 missing tags | model only | S2 codec vectors |
| ASCII, Windows-1252 | not implemented | S2 |
| Multi-member pull reader, tail policy | contract only | S2 |
| Streaming writer | contract only | S3 |
| inspect/export/write | build probe only | S4 |
| Three real datasets | oracle read only | not yet product validation |
| V8, SAS7BDAT, format execution | out of scope | reject distinctly |
