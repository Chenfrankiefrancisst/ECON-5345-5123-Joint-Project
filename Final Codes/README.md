# GPR Shock Analysis: Local Projection with Poisson Residualization

> **Last Updated:** 2026.05.23 22:45 PM  
> **Status:** Work in Progress

MATLAB code for extracting Geopolitical Risk (GPR) shocks and conducting Local Projection analysis.

## Overview

```
AR_GPR_shock.m          # Step 1: Extract GPR shocks
        ↓
Plot_GPR_shock.m        # (Optional) Visualize shocks
        ↓
LP_baseline.m           # Step 2a: Baseline LP analysis
LP_Poisson.m            # Step 2b: Poisson-residualized LP (3 events, overlay)
LP_Poisson_robust.m     # Step 2c: Poisson-residualized LP (6 events, robustness)
Poisson_shock_test.m    # Step 2d: Poisson shock diagnostics
```

## File Descriptions

### 1. `AR_GPR_shock.m`
**GPR Shock Extraction and Diagnostic Tests**

Extracts unpredictable innovations from GPR indices using an AR(4) model.

**Model:**
```
GPR_t = α + Σρ_j GPR_{t-j} + ξ'[Unemp_t, FFR_t] + ω'[Oil]_{t-1} + u_t
z_t = (u_t - mean(u)) / sd(u)
```

**Two variants:**
- `with_oil`: Includes lag-1 oil price controls (Brent, WTI, Gasoline)
- `without_oil`: Excludes oil price controls

**Diagnostic tests:**
- Granger exogeneity test (macro variables → shock)
- Ljung-Box Q test (white noise)
- Breusch-Godfrey LM test (serial correlation)

**Output:** `GPR_shock_output/`

---

### 2. `Plot_GPR_shock.m`
**GPR Shock Time Series Visualization**

Visualizes extracted GPR shocks (z_t) alongside major geopolitical events.

**Features:**
- Compares 3 shocks: World, GPT (Threats), GPA (Acts)
- Overlays with_oil vs without_oil variants
- Displays vertical lines for key events (9/11, Iraq War, Crimea, Ukraine, etc.)

**Output:** `GPR_shock_output/z_shocks_timeseries.{png,fig}`

---

### 3. `LP_baseline.m`
**Baseline Local Projection Analysis**

Estimates the dynamic effects of GPR shocks on oil prices and macroeconomic variables.

**Estimation model:**
```
y_{t+h} - y_{t-1} = α + β·z_t + controls + ε_{t+h}
```

**Features:**
- Newey-West HAC standard errors (bandwidth = h+1)
- 12-quarter horizon IRF
- Comparison dashboard: with_oil vs without_oil

**Output:** `LP_baseline_output/`

---

### 4. `LP_Poisson.m`
**Poisson-Residualized Local Projection Analysis**

Models event arrivals as a Poisson process and uses residuals in LP estimation.

**Step 1:** Load GPR shocks from `AR_GPR_shock.m` output

**Step 2:** Poisson event-arrival residualization
```
N_t^k ~ Poisson(λ_t^k)
log(λ_t^k) = α + β·z_t^{GPR} + controls
z_t^{N,k} = (N_t - λ_t) / sqrt(λ_t)  (Pearson residual, standardized)
```

**Step 3:** LP estimation (two variants)
- (a) Using Poisson residual: `y_{t+h} - y_{t-1} = α + β·z_t^{N,k} + ...`
- (b) Using raw event count: `y_{t+h} - y_{t-1} = α + β·N_t^k + ...`

**Step 4:** Overlay dashboard comparing (a) vs (b)

**Events analyzed:** 3 events (Chokepoint, StrictSupplyDisruption, EnergySanction)

**Output:** `LP_Poisson_output/`

---

### 5. `LP_Poisson_robust.m`
**Poisson-Residualized LP with Extended Robustness Checks**

Extended robustness analysis for Poisson event-arrival shocks with additional events and diagnostic tests.

**Step 1:** Load GPR shocks (aggregate from file, country-specific extracted on-the-fly)

**Step 2:** Baseline level LP for each GPR shock
```
y_{t+h} - y_{t-1} = α + β·z_t^{GPR} + controls + ε_{t+h}
```

**Step 3:** Poisson event-arrival residualization
```
N_t^k ~ Poisson(λ_t^k)
log(λ_t^k) = α + γ·z_t^{WorldGPR} + ψ'[GPR_{t-1}^{World}, GPR_{t-1}^{Threat}, GPR_{t-1}^{Act}] + ρ·N_{t-1}^k + η'W_{t-1}
z_t^{N,k} = (N_t - λ_hat) / sqrt(λ_hat)  (standardized Pearson residual)
```

**Step 4:** Joint LP with two impulses
```
y_{t+h} - y_{t-1} = α + θ·z_t^{WorldGPR} + β·z_t^{N,k} + controls + ε_{t+h}
```

**Step 5:** Robustness: raw event count N_t^k as additional control (FWL baseline)

**Events analyzed:** 6 events
- OilSpecificThreatShock_EventOnset
- OilSpecificRealizedShock_EventOnset
- StrictSupplyDisruption_EventOnset
- ChokepointShippingRisk_EventOnset
- EnergySanction_EventOnset
- ProducerRegionRisk_EventOnset

**Key differences from `LP_Poisson.m`:**
| Feature | LP_Poisson.m | LP_Poisson_robust.m |
|---------|--------------|---------------------|
| Events | 3 | 6 |
| Poisson intensity GPR | World only | World + Threat + Act |
| Primary output | Overlay comparison | Individual dashboards + diagnostics |
| Raw N_t robustness | No | Yes (as current control) |

**Output:** `LP_Poisson_robust_output/`

---

### 6. `Poisson_shock_test.m`
**Poisson Event-Arrival Shock Diagnostics**

Performs diagnostic tests on Poisson-residualized event shocks.

**Events analyzed:**
- Chokepoint shipping risk onset
- Strict supply disruption onset
- Energy sanction onset

**Diagnostic tests:**
- Conditional Granger exogeneity (manual OLS F-test)
- Ljung-Box Q white-noise test
- Breusch-Godfrey LM test

**Visualization:**
- Comparison of raw arrivals N_t^k and Poisson shocks z_t^{N,k}
- Oil-specific geopolitical episode timeline

**Output:** `Poisson_shock_tests_output/`

---

## Data Requirements

**Required files:**
- `Q_Levels_Database.csv` - Quarterly macroeconomic data
- `oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv` - Event dummies

## Execution Order

```matlab
% Step 1: Extract GPR shocks (required, run first)
run('AR_GPR_shock.m')

% Step 2: Visualization (optional)
run('Plot_GPR_shock.m')

% Step 3: LP analysis (choose as needed)
run('LP_baseline.m')         % Baseline LP
run('LP_Poisson.m')          % Poisson-residualized LP (3 events, overlay comparison)
run('LP_Poisson_robust.m')   % Poisson-residualized LP (6 events, robustness checks)
run('Poisson_shock_test.m')  % Poisson shock diagnostics
```

## Output Structure

```
GPR_shock_output/
├── gpr_shocks.csv                 # Extracted shock time series
├── gpr_shock_diagnostics.csv      # Extraction diagnostics (R², nobs)
├── granger_exog_test.csv          # Granger test results
├── white_noise_lbq.csv            # Ljung-Box Q test
├── white_noise_bg.csv             # Breusch-Godfrey test
├── workspace_gpr_shock.mat        # Full workspace saved
└── z_shocks_timeseries.{png,fig}  # Shock visualization

LP_baseline_output/
├── IRF_compare_*.{png,fig}        # IRF comparison plots
└── workspace_lp.mat               # LP results workspace

LP_Poisson_output/
├── overlay_*.{png,fig}            # Poisson vs Raw comparison
└── gpr_diagnostics_*.csv          # Diagnostic results

LP_Poisson_robust_output/
├── dashboard_*.{png,fig}                              # GPR shock LP dashboards
├── event_residual_dashboard_*.{png,fig}               # Poisson-residual event dashboards
├── joint_gpr_event_residual_dashboard_*.{png,fig}     # Joint GPR + event dashboards
├── level_lp_results_*.csv                             # Level LP results
├── level_lp_gpr_shock_diagnostics_*.csv               # GPR shock diagnostics
├── event_residual_lp_results_*.csv                    # Event residual LP results
├── event_joint_gpr_plus_poisson_results_*.csv         # Joint GPR + Poisson results
├── event_joint_gpr_plus_poisson_with_rawN_control_results_*.csv  # Robustness with raw N control
├── event_residual_poisson_diagnostics_*.csv           # Poisson model diagnostics
├── event_residual_nonGPR_resid_on_GPR_tests_*.csv     # GPR relation tests
└── workspace_level_lp_*.mat                           # Full workspace

Poisson_shock_tests_output/
├── poisson_shock_diagnostics.csv  # Poisson model diagnostics
├── poisson_shock_granger_exog.csv # Granger test results
├── poisson_shock_white_noise_*.csv # White noise tests
├── poisson_event_shocks.csv       # Event shock time series
└── event_arrivals_and_poisson_shocks_*.{png,fig}  # Visualization
```

