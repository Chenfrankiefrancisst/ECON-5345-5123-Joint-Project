# H1 — GPR as a Cost-Push Shock

> **H1.** A positive GPR shock raises CPI (inflation ↑) and lowers industrial production (output ↓) — the cost-push signature.

**Authors:** Nayeong KANG (SKKU), Frankie CHEN (HKUST), Bomi YUN (SKKU)
**Last updated:** 2026-04-12

---

## 1. Data

### 1.1 Variables

| Variable | Code | Source | Freq. | Start | Unit | Transformation |
|----------|------|--------|-------|-------|------|----------------|
| **Shock variables** |||||||
| GPR (headline) | — | [C&I](https://www.matteoiacoviello.com/gpr.htm) | M | 1900 | Index | log(GPR) |
| GPT (threats) | — | C&I | M | 1900 | Index | log(GPT) |
| GPA (acts) | — | C&I | M | 1900 | Index | log(GPA) |
| **Outcome variables** |||||||
| Industrial Production | `INDPRO` | FRED | M | 1919 | Index (2017=100) | log(IP) |
| CPI (headline) | `CPIAUCSL` | FRED | M | 1947 | Index (82-84=100) | log(CPI) |
| **Robustness controls** (not in baseline) |||||||
| Unemployment Rate | `UNRATE` | FRED | M | 1948 | Percent | Level |
| VIX | `VIXCLS` | FRED | D→M | 1990 | Index | log(VIX) |
| **Stage 4+ channel variables** (not in H1) |||||||
| Fed Funds Rate | `FEDFUNDS` | FRED | M | 1954 | Percent | Level |
| WTI Oil Price | `DCOILWTICO` | FRED | D→M | 1986 | USD/bbl | log(WTI) |

### 1.2 Stationarity

| Variable | Level | 1st Diff | Order |
|----------|-------|----------|-------|
| log(GPR), log(GPT), log(GPA) | Stationary / borderline | — | I(0) |
| log(IP), log(CPI) | Unit root | Stationary | I(1) |
| UNRATE | Unit root (persistent) | Stationary | I(1) |
| log(VIX) | Stationary / borderline | — | I(0) |

> The LP uses cumulative log differences as LHS (y_{t+h} − y_{t−1}), so I(1) variables are handled without pre-differencing.

### 1.3 Sample

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Start | 1985:01 | Post-Volcker disinflation; single monetary-policy regime |
| End | 2025:12 | Latest FRED vintage (April 2026) |
| *T* | ≈492 months | |
| COVID | Dummy 2020:03–2021:12 | Robustness: pre-COVID truncation (end 2020:02) |

*Binding constraint:* VIX starts 1990:01 → Robustness 2 uses ≈432 obs.

---

## 2. Model Specification

### 2.1 Local Projection (Jordà, 2005)

For each horizon *h* = 0, 1, ..., *H*:

```
y_{t+h} − y_{t−1} = α_h + β_h · shock_t + Σ γ_{h,ℓ} · y_{t−ℓ} + Σ δ_{h,ℓ} · shock_{t−ℓ} + ε_{t+h}
```

(sums from ℓ=1 to L)

| Component | Notation | Description |
|-----------|----------|-------------|
| Dependent variable | y_{t+h} − y_{t−1} | Cumulative log change in outcome (log IP or log CPI) from *t*−1 to *t*+*h*. Robust to I(1) variables. |
| Shock | shock_t | Contemporaneous log(GPR), log(GPT), or log(GPA). Three parallel regressions. |
| Own lags of outcome | y_{t−1}, ..., y_{t−L} | Absorb persistence and serial correlation. Prevent spurious long-horizon correlations. |
| Own lags of shock | shock_{t−1}, ..., shock_{t−L} | Absorb GPR persistence. Control for dynamic feedback: past GPR predicting future macro outcomes. |
| Constant | α_h | Horizon-specific intercept. |
| β_h (key coefficient) | — | IRF at horizon *h*. Cumulative log-point change in outcome per unit increase in log(shock). |

### 2.2 Why no additional controls in the baseline?

H1 tests the **total reduced-form effect**. Most macro variables are **mediators** (transmission channels), not confounders:

| Variable | Type | Causal path | Why excluded |
|----------|------|-------------|--------------|
| Oil (WTI) | Mediator | GPR → oil → CPI | Controlling removes the commodity-price channel |
| FFR | Mediator | GPR → π → Fed → FFR | Controlling removes the policy-response channel |
| Credit spread | Mediator | GPR → risk premia → spreads → investment | Controlling removes the financial channel |
| UNRATE | Potential confounder | See Robustness 1 | Included in robustness only |
| VIX | Potential confounder | See Robustness 2 | Included in robustness only |

**Identification assumption** (Caldara & Iacoviello, 2022): GPR is driven by geopolitical events exogenous to the US business cycle within the month. Under this assumption, own lags are sufficient for consistent estimation of β_h.

---

## 3. Robustness Controls

The robustness LP adds potential confounders to test whether β_h is sensitive:

```
y_{t+h} − y_{t−1} = α_h + β_h · shock_t + Σ γ · y_{t−ℓ} + Σ δ · shock_{t−ℓ} + Σ φ' · W_{t−ℓ} + ε_{t+h}
```

### Robustness 1: + UNRATE

| Aspect | Detail |
|--------|--------|
| **Why confounder** | Unemployment proxies the business-cycle state. A recession may (a) increase geopolitical tensions through political instability → raise GPR, and (b) independently affect inflation via the Phillips curve. |
| **Why NOT mediator** | GPR's primary transmission is supply-side (oil, commodities, expectations). GPR does not primarily affect inflation *through* unemployment. |
| **Literature** | Caldara et al. (2026, JIE) include output/employment controls in their country-panel. Ramey (2016, *Handbook*) recommends controlling for the business cycle when the shock's exogeneity is imperfect. |

### Robustness 2: + UNRATE + log(VIX)

| Aspect | Detail |
|--------|--------|
| **Why confounder** | Global uncertainty (VIX) could simultaneously raise news attention to geopolitical events (inflating GPR measurement) and depress investment/consumption (affecting macro outcomes). VIX measures *financial-market* uncertainty — a different dimension from GPR's *geopolitical* uncertainty. |
| **Why NOT mediator** | If GPR directly caused VIX, VIX would be a mediator. But Caldara & Iacoviello (2022, Table 3) show GPR and VIX are moderately correlated (ρ ≈ 0.3–0.4) but capture distinct constructs. The shared variation likely reflects common drivers, not unidirectional causation. |
| **Literature** | Baker, Bloom & Davis (2016, QJE) show EPU/VIX and GPR are related but not equivalent uncertainty measures. |
| **Sample note** | VIX starts 1990:01 → ≈432 months (vs 492 baseline). |

**Interpretation:** If β_h remains stable across all three specs → GPR exogeneity is supported. If β_h changes substantially → potential confounding, needs discussion.

---

## 4. Lag Selection

### 4.1 Baseline: L = 12

| Criterion | Detail |
|-----------|--------|
| Literature precedent | Caldara & Iacoviello (2022, AER) use 12 lags in their monthly VAR |
| Seasonality | 12 monthly lags span one full year, absorbing seasonal autocorrelation |
| Team consistency | Preliminary VAR work (`Prelim_OLS_MICH`) uses L=12 |
| Degrees of freedom | T≈492, 2 vars × 12 lags + 2 = 26 RHS. At h=36: T_eff ≈ 444, no concern |

### 4.2 Cross-check: VAR-based AIC/BIC

We estimate a reduced-form VAR(p) on [shock, log(IP), log(CPI)] for p = 1, ..., 24:

```
AIC(p) = log|Σ_p| + 2·K²·p / T_eff
BIC(p) = log|Σ_p| + K²·p·log(T_eff) / T_eff
```

Implemented in `lp_lag_select.m`, run at the start of `s03_run_h1.m`.

| AIC/BIC outcome | Action |
|-----------------|--------|
| Both select p=12 | L=12 confirmed |
| BIC < 12, AIC ≥ 12 | L=12 conservative but defensible; report BIC-optimal as robustness |
| Both ≪ 12 (e.g., p ≤ 6) | L=12 may be over-parameterised; report both |
| Both > 12 | L=12 may be insufficient; extend as robustness |

*Note:* LP does not require VAR-based lag selection. The cross-check ensures comparability with the VAR literature, not model selection for LP. See Plagborg-Møller & Wolf (2021, *Econometrica*).

---

## 5. Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| *H* (max horizon) | 36 months | 3 years; captures hump-shaped response (Caldara et al., 2024) |
| *L* (lag length) | 12 | See Section 4; cross-checked by VAR AIC/BIC |
| α (CI level) | 0.10 | 90% confidence bands |
| SE method | Newey-West HAC | Bandwidth = max(h, ⌊4(T/100)^(2/9)⌋) |
| Critical value | z = 1.645 | 90% two-sided |

LP residuals are MA(*h*) by construction → HAC correction essential at all h > 0.

---

## 6. Deliverable — IRF Figures

### 6-Panel IRF (per specification)

|  | IP response (expected: −) | CPI response (expected: +) |
|--|---------------------------|----------------------------|
| GPR (headline) | β_h(log IP | GPR) | β_h(log CPI | GPR) |
| GPT (threats) | β_h(log IP | GPT) | β_h(log CPI | GPT) |
| GPA (acts) | β_h(log IP | GPA) | β_h(log CPI | GPA) |

Produced for: baseline, robustness 1, robustness 2, plus overlay comparison.

---

## 7. Success Criterion

**H1 is supported if**, for at least one shock variant (GPR / GPT / GPA) at horizons *h* ≈ 6–24 months:
- CPI impulse response is **significantly positive** (inflation ↑)
- IP impulse response is **significantly negative** (output ↓)

This constitutes the **cost-push signature**. The result should be robust across specifications.

---

## 8. Code Structure

### 8.1 Folder layout

```
Feedback_Pf.Baek/H1/
├── run_all.m                  ← master script (run this one file)
├── README_H1.md               this document
├── README_H1.tex              LaTeX version (for Overleaf)
├── scripts/
│   ├── download_data.sh       Step 0: download raw data (bash)
│   ├── s01_load_data.m        Step 1: load, merge, transform
│   ├── s02_explore_data.m     Step 2: descriptive analysis
│   └── s03_run_h1.m           Step 3: LP estimation + robustness
├── code/                      reusable functions (called by s03)
│   ├── lp_estimate.m          LP estimation + Newey-West SE
│   ├── lp_newey_west.m        Newey-West HAC standard errors
│   ├── lp_lag_select.m        VAR-based AIC/BIC lag selection
│   └── lp_plot_irf.m          IRF plotting with confidence bands
├── data/
│   ├── raw/                   populated by download_data.sh
│   └── h1_baseline.mat        created by s01 (not committed)
└── output/                    figures + results (created by scripts)
```

### 8.2 How to run

**Prerequisites:** MATLAB (R2020a or later recommended).

**MATLAB에서 이것 하나만 실행하면 됩니다:**

```matlab
run('Feedback_Pf.Baek/H1/run_all.m')
```

`run_all.m`이 raw 데이터가 없으면 자동으로 다운로드한 뒤, 전체 파이프라인을 순서대로 실행합니다:

| Internal step | Script | What it does | Output |
|---------------|--------|-------------|--------|
| 1/3 | `s01_load_data.m` | Load raw CSV/XLS → aggregate daily→monthly → merge → log transform → save | `data/h1_baseline.mat` |
| 2/3 | `s02_explore_data.m` | Summary statistics, time series plots, ADF unit root tests, correlation matrix, ACF | `output/fig_*.png` (5 figures) |
| 3/3 | `s03_run_h1.m` | VAR AIC/BIC lag selection → Baseline LP → Robustness 1 (+UNRATE) → Robustness 2 (+UNRATE+VIX) → overlay comparison | `output/fig_h1_*.png` (5 figures), `output/h1_results.mat` |

**Alternatively**, you can run each step individually in MATLAB:

```matlab
run('Feedback_Pf.Baek/H1/scripts/s01_load_data.m')    % step 1
run('Feedback_Pf.Baek/H1/scripts/s02_explore_data.m')  % step 2
run('Feedback_Pf.Baek/H1/scripts/s03_run_h1.m')        % step 3
```

Functions in `code/` (`lp_estimate.m`, `lp_newey_west.m`, `lp_lag_select.m`, `lp_plot_irf.m`) are called internally by `s03` — do not run them directly.

---

## 9. References

- Baker, S.R., Bloom, N. & Davis, S.J. (2016). "Measuring Economic Policy Uncertainty." *QJE*, 131(4), 1593–1636.
- Caldara, D. & Iacoviello, M. (2022). "Measuring Geopolitical Risk." *AER*, 112(4), 1194–1225.
- Caldara, D., Conlisk, S., Iacoviello, M. & Penn, M. (2026). "Do Geopolitical Risks Raise or Lower Inflation?" *JIE*, 159.
- Jordà, Ò. (2005). "Estimation and Inference of Impulse Responses by Local Projections." *AER*, 95(1), 161–182.
- Lütkepohl, H. (2005). *New Introduction to Multiple Time Series Analysis*. Springer.
- Newey, W.K. & West, K.D. (1987). "A Simple, Positive Semi-Definite, Heteroskedasticity and Autocorrelation Consistent Covariance Matrix." *Econometrica*, 55(3), 703–708.
- Plagborg-Møller, M. & Wolf, C.K. (2021). "Local Projections and VARs Estimate the Same Impulse Responses." *Econometrica*, 89(2), 955–980.
- Ramey, V.A. (2016). "Macroeconomic Shocks and Their Propagation." *Handbook of Macroeconomics*, Vol. 2, 71–162.
