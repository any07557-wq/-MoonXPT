# ADR 002: SAS-compatible toward-zero IBM decoding

2026-11-04, S5. Initially the reader rounded a 56-bit IBM fraction to the nearest
53-bit IEEE significand. An extremal counterexample is `7f ff ff ff ff ff ff ff`:
the exact normalized HFP value is less than 2^252, but nearest Double is 2^252,
which the writer must reject as unrepresentable. That breaks semantic export /
rebuild for a legal source value.

The final semantic view truncates toward zero, matching the SAS convenience
reader and ReadStat family. Error is strictly below one ULP of the finite
IEEE value. It keeps the entire normalized HFP range inside the encodable IEEE
subset. Original IBM bytes, including discarded 1–3 low bits and signed zero,
remain available in Observation.raw / next_raw; write_raw retains them.
Finite zero writes canonical positive zero. Widths 2–8 follow SAS truncation.
NaN/infinity, malformed zero exponents and unnormalized nonzero fractions fail
explicitly in the semantic decoder; next_raw still exposes original fields.

Independent 128-vector expectations were intentionally regenerated for this
published policy change, using exact Python Fraction: select the nearest float,
and only step toward zero if its exact rational magnitude exceeds the input.
This is independent of the bit-shift implementation and does not change a
floating tolerance to hide an implementation failure. Regression tests include
the extremal vector and decode→encode→decode stability. All three real datasets
are rerun with exact pyreadstat comparisons after the change.
