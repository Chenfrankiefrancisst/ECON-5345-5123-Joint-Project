# Feedback from Prof. Baek — GPR as a Cost-Push Shock

**Author:** Nayeong KANG (SKKU)
**Status:** Brainstorming / preliminary
**Last updated:** 2026-04-07

This subfolder explores the research direction suggested by **Prof. Chaewon Baek** during the team brainstorming stage. It is independent of `SVAR/` (Frankie's thesis material) and `Prelim_OLS_MICH/` (joint preliminary work).

---

## 1. Research question

> **Does a Geopolitical Risk (GPR) shock act as a cost-push shock to the US economy, and if so, through which channels?**

The motivating idea (from Prof. Baek):

1. First establish whether GPR shocks behave like a *cost-push* disturbance — i.e., raising inflation while contracting output.
2. If yes, decompose the response into specific transmission **channels** (oil, raw materials, expected inflation, credit spread, ...).
3. Identify which channel is **dominant**.
4. Interpret the result as a rationale for the Federal Reserve's interest-rate response, and/or motivate a follow-up study.

**Methodological steer (Prof. Baek):** Use **Local Projections** (Jordà 2005) as the primary estimation method. LP is more robust to specification error than VAR, accommodates nonlinearities and state dependence naturally, and gives horizon-by-horizon impulse responses with clean inference.

## 2. Working hypotheses

- **H1.** A positive GPR shock raises CPI/PPI and lowers industrial production — the cost-push signature.
- **H2.** The effect operates primarily through commodity-price channels (oil, raw materials) rather than demand-side channels.
- **H3.** Expected inflation responds positively, amplifying the cost-push effect.
- **H4.** The Fed responds by raising the policy rate — consistent with a Taylor rule augmented by GPR.

## 3. Channels to investigate

| # | Channel | Proxy variable(s) | Source |
|---|---------|-------------------|--------|
| 1 | Oil price | WTI, Brent crude | FRED: `DCOILWTICO`, `DCOILBRENTEU` |
| 2 | Raw materials | PPI: industrial commodities, BCOM index | FRED: `WPU03THRU15`, Bloomberg BCOM |
| 3 | Expected inflation | Michigan E[π], FRBNY SCE 1y | FRED: `MICH`, NY Fed SCE |
| 4 | Credit spread | BAA-AAA spread, GZ spread | FRED: `BAA10Y`, Gilchrist-Zakrajšek |

See [`notes/channels.md`](notes/channels.md) for the per-channel rationale, expected sign, and identification notes.

## 4. Folder structure

```
Feedback_Pf.Baek/
├── README.md          this file
├── notes/
│   ├── channels.md    per-channel mechanism, data, prior work
│   └── meetings.md    feedback summaries from Prof. Baek and team
├── data/              raw + processed data
├── code/              MATLAB scripts (numbered by stage)
└── output/            figures, tables
```

## 5. Plan of work

1. **Stage 0 — Notes.** Fill in `notes/channels.md`: mechanism, proxy choice, prior literature.
2. **Stage 1 — Data.** Pull the GPR index (Caldara & Iacoviello, 2022) plus US monthly macro and channel proxies.
3. **Stage 2 — Design lock.** Specify the baseline LP (LHS variables, controls, lag length, sample, shock variable, confidence interval method) **before** estimating anything.
4. **Stage 3 — Baseline LP.** Estimate horizon-by-horizon LP of (log) IP and (log) CPI on the GPR shock; confirm the cost-push signature (π ↑, y ↓).
5. **Stage 4 — Channel LPs.** For each channel: (a) LP of the channel variable on the GPR shock, (b) LP of inflation on the GPR shock controlling for the channel, to assess attenuation.
6. **Stage 5 — Channel ranking.** Compare attenuation magnitudes / share of inflation response explained by each channel. Optional: mediation-style decomposition.
7. **Stage 6 — Fed response.** LP of the Fed funds rate (or shadow rate) on the GPR shock; interpret as augmented Taylor rule reaction.
8. **Stage 7 — Summary.** Write up in the team Overleaf.

## 6. Methodological notes — Local Projections

- **Estimator:** OLS, horizon-by-horizon, $h = 0, 1, \dots, H$.
- **Specification (baseline):**
  $$y_{t+h} - y_{t-1} = \alpha_h + \beta_h \, \text{shock}_t + \sum_{l=1}^{L} \gamma_{h,l} \, X_{t-l} + u_{t+h}$$
  where the IRF at horizon $h$ is $\beta_h$, and $X$ stacks lags of $y$, the shock, and any controls.
- **Inference:** Newey–West HAC with bandwidth $\geq h$ (LP residuals are MA($h$) by construction).
- **Channel test:** Add the contemporaneous channel variable on the RHS — if $\beta_h$ shrinks toward zero, that channel carries the response.
- **Reference implementation already in repo:** `code/` of this subfolder will reuse the LP routine pattern from PS3 (`PS3_Answer_NY.m`, Q7) — same `ols_nw` helper and `t+h − t−1` LHS construction.

## 7. Open questions

- Which sample period? (Full post-1985 vs. post-2000 to avoid the Great Moderation break)
- Shock construction: raw GPR innovations, residuals from an AR, or external proxy (Caldara–Iacoviello shock series)?
- Linear LP vs. state-dependent LP (high-GPR vs. low-GPR regimes; size/sign asymmetry à la Caldara et al. 2024)?
- Lag length $L$: AIC/BIC, or fixed at 12 following the team's preliminary work?

## 8. References (to be filled)

- Jordà, Ò. (2005). *Estimation and inference of impulse responses by local projections.* AER.
- Caldara & Iacoviello (2022). *Measuring Geopolitical Risk.* AER.
- Caldara, Conlisk, Iacoviello & Penn (2024). *Do geopolitical risks raise or lower inflation?*
- Gilchrist & Zakrajšek (2012). *Credit spreads and business cycle fluctuations.* AER.
