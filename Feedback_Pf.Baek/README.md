# Feedback from Prof. Baek — GPR as a Cost-Push Shock

**Author:** Nayeong KANG (SKKU)
**Status:** H1 baseline in progress (Stage 2–3)
**Last updated:** 2026-04-12

This subfolder explores the research direction suggested by **Prof. Chaewon Baek** during the team brainstorming stage. It is independent of `SVAR/` (Frankie's thesis material) and `Prelim_OLS_MICH/` (joint preliminary work).

---

## 1. Research question

> **Does a Geopolitical Risk (GPR) shock act as a cost-push shock to the US economy, and if so, through which channels? Do *threats* (GPT) and *acts* (GPA) transmit differently?**

The motivating idea (from Prof. Baek):

1. First establish whether GPR shocks behave like a *cost-push* disturbance — i.e., raising inflation while contracting output.
2. If yes, decompose the response into specific transmission **channels** (oil, raw materials, expected inflation, credit spread, ...).
3. Identify which channel is **dominant**.
4. Interpret the result as a rationale for the Federal Reserve's interest-rate response, and/or motivate a follow-up study.

**Shock decomposition (own extension).** Caldara & Iacoviello (2022) construct the headline GPR index as the sum of two sub-indices:

- **GPT — Geopolitical Threats:** news mentioning *risks* of war, terror, or military tension (forward-looking, expectational).
- **GPA — Geopolitical Acts:** news reporting *realised* events (war outbreaks, attacks, invasions).

Aggregating into a single GPR index can mask very different transmission mechanisms — threats may operate mainly through **expectations and risk premia**, while acts may operate through **physical supply disruption** (oil, shipping, commodities). I will run the entire analysis (baseline + each channel) **separately for GPT and GPA**, then compare.

**Methodological steer (Prof. Baek):** Use **Local Projections** (Jordà 2005) as the primary estimation method. LP is more robust to specification error than VAR, accommodates nonlinearities and state dependence naturally, and gives horizon-by-horizon impulse responses with clean inference.

## 2. Working hypotheses

- **H1.** A positive GPR shock raises CPI/PPI and lowers industrial production — the cost-push signature.
- **H2.** The effect operates primarily through commodity-price channels (oil, raw materials) rather than demand-side channels.
- **H3.** Expected inflation responds positively, amplifying the cost-push effect.
- **H4.** The Fed responds by raising the policy rate — consistent with a Taylor rule augmented by GPR.
- **H5 (GPT vs. GPA).** *Threats* (GPT) transmit primarily through expectations and credit-spread / risk-premium channels; *acts* (GPA) transmit primarily through physical commodity-price (oil, raw materials) channels. The two should therefore have distinct dominant channels and possibly different inflation persistence.

## 3. Channels to investigate

See [`notes/channels.md`](notes/channels.md) for the full proxy table, per-channel rationale, expected sign, and identification notes.

## 4. Folder structure

```
Feedback_Pf.Baek/
├── README.md                 this file
├── notes/
│   ├── channels.md           per-channel mechanism, data, prior work
│   ├── literature_h1.md      literature review for H1
│   └── meetings.md           feedback summaries from Prof. Baek and team
├── data/
│   └── README.md             data dictionary with variable details
└── H1/                       ★ H1 analysis (self-contained)
    ├── run_all.m             이 파일 하나만 실행 (다운로드+분석)
    ├── README_H1.md          H1 spec (data, model, parameters)
    ├── README_H1.tex         LaTeX version (for Overleaf, 결과 포함)
    ├── scripts/
    │   ├── s02_explore_data.m  descriptive analysis
    │   └── s03_run_h1.m      LP estimation + robustness
    ├── code/                 reusable LP functions
    │   ├── lp_estimate.m     Local Projection (Jorda 2005)
    │   ├── lp_newey_west.m   Newey-West HAC standard errors
    │   ├── lp_lag_select.m   VAR-based AIC/BIC lag selection
    │   └── lp_plot_irf.m     IRF plotting with confidence bands
    ├── data/
    │   └── raw/              auto-downloaded by run_all
    └── output/               figures + results (created by run_all)
```

## 4a. How to run H1

**Prerequisites:** MATLAB (R2020a+).

```matlab
% MATLAB에서 이것 하나만 실행:
run('Feedback_Pf.Baek/H1/run_all.m')
```

`run_all.m`이 raw 데이터 자동 다운로드 → s01 → s02 → s03 순차 실행. Output: `H1/output/`.

> **H1 details** (data, model spec, parameters, deliverables): see [`H1/README_H1.md`](H1/README_H1.md) | LaTeX: [`H1/README_H1.tex`](H1/README_H1.tex)

## 5. Plan of work

1. **Stage 0 — Notes.** Fill in `notes/channels.md`: mechanism, proxy choice, prior literature.
2. **Stage 1 — Data.** Pull the GPR index (Caldara & Iacoviello, 2022) plus US monthly macro and channel proxies.
3. **Stage 2 — Design lock.** Specify the baseline LP (LHS variables, controls, lag length, sample, shock variable, confidence interval method) **before** estimating anything.
4. **Stage 3 — Baseline LP.** Estimate horizon-by-horizon LP of (log) IP and (log) CPI on the shock; confirm the cost-push signature (π ↑, y ↓). **Run three variants in parallel: headline GPR, GPT only, GPA only.**
5. **Stage 4 — Channel LPs.** For each channel × each shock (GPT, GPA): (a) LP of the channel variable on the shock, (b) LP of inflation on the shock controlling for the channel, to assess attenuation.
6. **Stage 5 — Channel ranking.** Compare attenuation magnitudes / share of inflation response explained by each channel — separately for GPT and GPA. Test whether the dominant channel differs across the two.
7. **Stage 6 *(optional, time-permitting)* — Threshold-based magnitude analysis.** Split the shock series into *small* and *large* events using a standard-deviation threshold (e.g. $|\text{shock}_t| < 1\sigma$ vs. $\geq 1\sigma$, or $1\sigma$ / $2\sigma$ bins), then re-estimate the baseline LP within each bin. Implementation options: (a) state-dependent LP with a dummy interaction, $\beta_h^{\text{small}}$ vs. $\beta_h^{\text{large}}$; (b) separate LP on the two sub-samples. Run for GPT and GPA independently. Goal: test whether GPR transmits *nonlinearly* — large geopolitical shocks may trigger disproportionate cost-push effects (consistent with Caldara et al. 2024's nonlinearity finding). This addresses the *size effect* question without committing to a fully nonparametric specification.
8. **Stage 7 *(optional, time-permitting)* — Fed response.** LP of the Fed funds rate (or shadow rate) on each shock; interpret as augmented Taylor rule reaction. Check whether the Fed reacts differently to threats vs. acts. *Reason for downgrading to optional:* per Prof. Baek, naive OLS suffers from endogeneity and the Taylor rule is notoriously hard to estimate cleanly — pursue only after Stages 3–5 deliver a credible cost-push result.
9. **Stage 8 — Summary.** Write up in the team Overleaf.

## 6. Methodological notes — Local Projections

## 7. Open questions

- Which sample period? (Full post-1985 vs. post-2000 to avoid the Great Moderation break)
- Shock construction: raw GPR/GPT/GPA innovations, residuals from an AR, or external proxy (Caldara–Iacoviello narrative shock series)?
- When running GPT and GPA jointly in one LP, how to order them? Or run separately and compare? (Default: separate, to keep the IRF interpretation clean.)
- Linear LP vs. state-dependent LP (high-GPR vs. low-GPR regimes; size/sign asymmetry à la Caldara et al. 2024)?
- Lag length $L$: AIC/BIC, or fixed at 12 following the team's preliminary work?

## 8. References (to be filled)

- Jordà, Ò. (2005). *Estimation and inference of impulse responses by local projections.* AER.
- Caldara & Iacoviello (2022). *Measuring Geopolitical Risk.* AER.
- Caldara, Conlisk, Iacoviello & Penn (2024). *Do geopolitical risks raise or lower inflation?*
- Gilchrist & Zakrajšek (2012). *Credit spreads and business cycle fluctuations.* AER.
