# Data Dictionary — H1 Baseline

## Overview

This folder contains data for **H1: GPR as a cost-push shock** (inflation ↑, output ↓).
Only the variables needed for the H1 baseline LP are included. Channel-specific data (oil decomposition, credit spreads, expected inflation proxies) will be added at Stage 4.

**Sample period:** 1985-01 to 2025-12 (492 months)

## Raw Data Files (`raw/`)

Download by running: `bash scripts/download_data.sh`

### Shock Variables

| File | Series | Source | Frequency | Coverage | Unit | Notes |
|------|--------|--------|-----------|----------|------|-------|
| `gpr_caldara_iacoviello.xls` | GPR, GPT, GPA | [Caldara & Iacoviello](https://www.matteoiacoviello.com/gpr.htm) | Monthly | 1900-01 – present | Index | GPR = headline; GPT = threats sub-index; GPA = acts sub-index. Constructed from newspaper article shares across 11 broadsheet papers. |

### LHS Variables (Outcome)

| File | Series | FRED Code | Frequency | Coverage | Unit | Notes |
|------|--------|-----------|-----------|----------|------|-------|
| `industrial_production__INDPRO.csv` | Industrial Production Index | `INDPRO` | Monthly | 1919-01 – present | Index (2017=100) | Seasonally adjusted. Measures real output of manufacturing, mining, and utilities. |
| `cpi_all_urban__CPIAUCSL.csv` | CPI All Urban Consumers | `CPIAUCSL` | Monthly | 1947-01 – present | Index (1982-84=100) | Seasonally adjusted. Headline CPI — the price-leg outcome for the cost-push test. |

### Additional Variables (for exploration and future stages)

These are loaded by `s01_load_data.m` for descriptive analysis but are **not used as controls in the H1 baseline LP**. They are mediators (transmission channels), not confounders — including them would attenuate the total effect we measure in H1. They will be added as controls in Stage 4–5 (channel decomposition).

| File | Series | FRED Code | Frequency | Coverage | Unit | Notes |
|------|--------|-----------|-----------|----------|------|-------|
| `fed_funds_rate__FEDFUNDS.csv` | Effective Federal Funds Rate | `FEDFUNDS` | Monthly | 1954-07 – present | Percent (annual rate) | Mediator: monetary policy response channel. |
| `oil_wti__DCOILWTICO.csv` | WTI Crude Oil Spot Price | `DCOILWTICO` | **Daily** → Monthly | 1986-01 – present | USD / barrel | Mediator: oil/commodity channel. **Daily → monthly average.** |

## Processed Data

| File | Content | Created by |
|------|---------|------------|
| `h1_baseline.mat` | Master monthly panel with all variables + log transformations | `s01_load_data.m` |

## Variable Transformations

All transformations are applied in `s01_load_data.m`:

| Variable | Transformation | LP role | Expected sign (H1) |
|----------|---------------|---------|---------------------|
| `log_GPR` | log(GPR) | Shock (key regressor) | — |
| `log_GPT` | log(GPT) | Shock (threats) | — |
| `log_GPA` | log(GPA) | Shock (acts) | — |
| `log_IP` | log(INDPRO) | LHS outcome | Negative (output ↓) |
| `log_CPI` | log(CPIAUCSL) | LHS outcome | Positive (inflation ↑) |
| `FFR` | No transformation | Exploration / Stage 4+ | — |
| `log_WTI` | log(WTI) | Exploration / Stage 4+ | — |

## Stationarity Properties (Expected)

| Variable | Level | First Diff | Integration Order |
|----------|-------|------------|-------------------|
| log(GPR/GPT/GPA) | Likely stationary or weakly persistent | — | I(0) or borderline |
| log(IP) | Unit root | Stationary | I(1) |
| log(CPI) | Unit root | Stationary | I(1) |
| FFR | Unit root (persistent) | Stationary | I(1) |
| log(WTI) | Unit root | Stationary | I(1) |

**Note:** The LP uses cumulative log differences as LHS (y_{t+h} − y_{t−1}), which is robust to I(1) variables. Formal ADF results are produced by `s02_explore_data.m`.

## Sample Period Rationale

- **Start 1985-01:** Post-Volcker disinflation → single monetary-policy regime.
- **End 2025-12:** Latest available FRED vintage as of April 2026.
- **COVID treatment:** Dummy for 2020-03 to 2021-12 recommended (see literature_h1.md).
- **Binding constraint:** WTI oil data starts 1986-01. The panel starts at whichever series begins latest within the 1985+ window.
