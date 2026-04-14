## Files

- **Result summary**: `First_stage_ver_1.pdf`
- **Code**: Download all Matlab files in the `codes` folder and run the program.

## Updates

- **`codes/run_h1_simple_v2.m`**: Revised version of `run_h1_simple.m` (v1).
  Selected blocks were modified; see the in-file English comments for the
  specific changes (main items: ADF unit-root checks added at the top of
  Section 0, sample unified to 1990:01--2025:12, LP LHS switched to
  log-level so that `ir_jorda` forms $y_{t+h}-y_{t-1}$ internally, and
  VIX control entered as $\log(\mathrm{VIX})$ in level).
- **`H1_v.overleaf_260414.pdf`**: Result summary corresponding to
  `run_h1_simple_v2.m`. Reports ADF diagnostics, ADL and LP impulse
  responses under Baseline / R1 (+UNRATE) / R2 (+UNRATE+$\log$VIX)
  specifications, and the ADL-vs-LP cross-check --- all on the unified
  1990--2025 sample.
