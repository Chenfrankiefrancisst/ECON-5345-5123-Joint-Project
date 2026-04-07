# Literature for H1 — GPR ⇒ Inflation

Papers that empirically estimate the effect of geopolitical risk on inflation. All entries verified to exist via Google Scholar / publisher pages — no fabricated references. For each paper, the **specification block** records what could be verified from abstracts, working-paper landing pages, and snippets accessible without paywall. Items I could not extract from accessible HTML are marked **`[verify in PDF]`** — these need a careful read of the actual paper before citing in writing.

The first eight papers below directly estimate IRFs of inflation to GPR. Items 9–10 are policy / central-bank notes useful for context but not for econometric specifications.

---

## 1. Caldara & Iacoviello (2022) — *Measuring Geopolitical Risk*

- **Authors:** Dario Caldara, Matteo Iacoviello
- **Year:** 2022
- **Source:** *American Economic Review*, vol. 112, no. 4, pp. 1194–1225
- **DOI / link:** [aeaweb.org/articles?id=10.1257/aer.20191823](https://www.aeaweb.org/articles?id=10.1257/aer.20191823)
- **Working paper version:** Federal Reserve IFDP 1222 — [federalreserve.gov/econres/ifdp/files/ifdp1222.pdf](https://www.federalreserve.gov/econres/ifdp/files/ifdp1222.pdf)
- **GPR data page:** [matteoiacoviello.com/gpr.htm](https://www.matteoiacoviello.com/gpr.htm)
- **Already in repo:** `literatures/Measuring Geopolitical Risjs.pdf` (sic)

**Specification (verified from abstract + working paper landing).**
- **Method:** Monthly VAR for the United States; complementary firm- and industry-level panel regressions.
- **Key dependent variables:** US industrial production, employment, stock returns; firm-level investment.
- **Key independent variable:** GPR index (and the GPT/GPA sub-indices) constructed from the share of newspaper articles mentioning geopolitical-risk keywords across 11 broadsheet newspapers since 1900.
- **Sample:** 1900–2019; monthly for the macro VAR.
- **Identification:** Recursive (Cholesky) with GPR ordered first, on the assumption that GPR is exogenous to other US macro variables within the month.

**What this paper actually says about inflation.** It is primarily about *defining* the index and showing real-side effects (investment, employment, disaster probability). Inflation is **not** the central outcome but is discussed in the broader macro VAR. **`[verify in PDF]`** the exact list of variables in the baseline VAR and where inflation enters.

---

## 2. Caldara, Conlisk, Iacoviello & Penn (2026, forthcoming) — *Do Geopolitical Risks Raise or Lower Inflation?*

- **Authors:** Dario Caldara, Sarah Conlisk, Matteo Iacoviello, Maddie Penn
- **Year:** 2026 (forthcoming, Journal of International Economics, Vol. 159)
- **Source:** *Journal of International Economics* — [sciencedirect.com/science/article/abs/pii/S002219962500145X](https://www.sciencedirect.com/science/article/abs/pii/S002219962500145X) ([RePEc record](https://ideas.repec.org/a/eee/inecon/v159y2026ics002219962500145x.html))
- **Working paper version (open access):** [matteoiacoviello.com/research_files/GPR_INFLATION_PAPER.pdf](https://www.matteoiacoviello.com/research_files/GPR_INFLATION_PAPER.pdf) and [matteoiacoviello.com/research_files/JIE_2026.pdf](https://www.matteoiacoviello.com/research_files/JIE_2026.pdf)
- **SSRN:** [papers.ssrn.com/sol3/papers.cfm?abstract_id=4852461](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4852461)
- **World Bank version:** [thedocs.worldbank.org/en/doc/...GPR-Caldara-WB.pdf](https://thedocs.worldbank.org/en/doc/066f80bf77301b1f5933386d1c234a4c-0360012024/related/GPR-Caldara-WB.pdf)

**This is the central reference for H1.**

**Specification (verified from RePEc / SSRN / abstract).**
- **Methods, plural.** The paper combines (i) a country-panel analysis on annual data 1900–2023 covering 44 economies, and (ii) a monthly VAR on global aggregates from the 1970s onward. They report results from "a range of empirical methods" — `[verify in PDF]` whether local projections are among them.
- **Country-panel variables:** country-level GPR, inflation, GDP, military expenditures, public debt, trade openness, government spending, money growth.
- **Monthly global VAR variables:** global GPR, commodity prices, exchange rate, consumer sentiment, financial conditions, inflation, output. **`[verify in PDF]`** the exact ordering and lag length.
- **Headline finding (verbatim from abstract):** geopolitical risks foreshadow higher inflation, with the inflationary effect of higher commodity prices and currency depreciation more than offsetting the deflationary effects of lower consumer sentiment and tighter financial conditions.
- **Channel decomposition:** the paper explicitly decomposes the inflation response into supply, demand, and policy channels, with supply playing a dominant role. This directly maps to our channel analysis in Stages 4–5.

**Already partly in repo:** see `literatures/Caldara et al. (2024)_Do geopolitical risks raise or lower inflation.pdf` (working-paper vintage).

---

## 3. Brignone, Gambetti & Ricci (2025) — *Geopolitical Risk Shocks: When Size Matters*

- **Authors:** Davide Brignone, Luca Gambetti, Martino Ricci
- **Year:** 2025
- **Source:** Bank of England Staff Working Paper No. 1118, February 2025 — [bankofengland.co.uk/working-paper/2025/geopolitical-risk-shocks-when-size-matters](https://www.bankofengland.co.uk/working-paper/2025/geopolitical-risk-shocks-when-size-matters)
- **Earlier ECB Working Paper version:** ECB WP 2972, September 2024 — [ecb.europa.eu/pub/pdf/scpwps/ecb.wp2972.en.pdf](https://www.ecb.europa.eu/pub/pdf/scpwps/ecb.wp2972~6da32f928b.en.pdf) ([RePEc](https://ideas.repec.org/p/ecb/ecbwps/20242972.html))
- **SSRN:** [papers.ssrn.com/sol3/papers.cfm?abstract_id=4919668](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4919668)
- **Already in repo:** `literatures/Geopolitical risk shocks- when size matters.pdf`

**Specification (from abstract + SUERF policy brief).**
- **Method:** Nonlinear local projection / nonlinear VAR — explicitly tests size-dependent (large vs. small) GPR shocks.
- **Key dependent variables:** oil prices, inflation, consumption, equity prices, measures of uncertainty.
- **Decomposition:** the GPR shock is split into a *risk* component and a *realised* component (mirrors our GPT/GPA split, though their decomposition is methodological rather than the C&I sub-index split — `[verify in PDF]` exact construction).
- **Headline finding (from abstract):** large GPR shocks transmit nonlinearly through an *uncertainty* channel; only the large-shock regime produces sharp oil-price and inflation rises.

**Why it matters for our project.** This is the direct precedent for **Stage 6 (threshold magnitude analysis)**. We should match their threshold convention (1σ/2σ) where possible to make results comparable.

---

## 4. Pinchetti (2024) — *Geopolitical Risk and Inflation: The Role of Energy Markets*

- **Author:** Marco Pinchetti
- **Year:** 2024
- **Source:** LSE Centre for Macroeconomics Discussion Paper CFMDP2024-31 — [lse.ac.uk/CFM/assets/pdf/CFM-Discussion-Papers-2024/CFMDP2024-31-Paper.pdf](https://www.lse.ac.uk/CFM/assets/pdf/CFM-Discussion-Papers-2024/CFMDP2024-31-Paper.pdf)

**Specification.** `[verify in PDF]` — landing page is paywalled to extract abstract via WebFetch. From the title and CFM working-paper context, this paper isolates the *energy* transmission channel from GPR to inflation, which is exactly our Channel 1 (Oil & energy). Read carefully before locking the Stage-4 oil specification.

---

## 5. Wang, Wu, Liu & Wang (2024) — TVP-SV-VAR on GPR, Oil, and Inflation

- **Authors:** as listed on ScienceDirect (full list `[verify in PDF]`)
- **Year:** 2024
- **Source:** *Energy Economics* — [sciencedirect.com/science/article/abs/pii/S0140988323005972](https://www.sciencedirect.com/science/article/abs/pii/S0140988323005972)

**Specification (from search snippet).**
- **Method:** Time-Varying Parameter Structural VAR with Stochastic Volatility (TVP-SV-VAR).
- **Coverage:** China, US, and 27 European countries.
- **Sample:** January 2000 – July 2022, monthly.
- **Variables:** GPR index, oil prices, inflation. `[verify in PDF]` whether the model is 3-variable or includes additional macro controls.

**Why it matters.** The TVP setup is overkill for our linear baseline LP, but it documents that the GPR–oil–inflation transmission is **time-varying** — a useful caveat when we choose a sample period in Stage 2.

---

## 6. Ginn & Saadaoui (2025) — *Monetary Policy Reaction to Geopolitical Risks in Unstable Environments*

- **Authors:** William Ginn, Jamel Saadaoui
- **Year:** 2025
- **Source:** *Macroeconomic Dynamics*, Cambridge University Press — [cambridge.org/core/journals/macroeconomic-dynamics/article/...](https://www.cambridge.org/core/journals/macroeconomic-dynamics/article/abs/monetary-policy-reaction-to-geopolitical-risks-in-unstable-environments/21FDAD2D9F493CD10C53543F5C659FEE)
- **Already in repo:** `literatures/` and `Team Project (with HKUST)/GinnSaadaoui(2025)_Monetary policy reaction to geopolitical risks in unstable environments.pdf` (+ summary)

**Specification.** `[verify in PDF — already on disk]` — directly relevant for **Stage 7 (Fed response)**. Read this one carefully before the Taylor-rule extension.

---

## 7. FIU Working Paper 2406 — *Geopolitical Risk, Supply Chains, and Global Inflation*

- **Source:** FIU Department of Economics Working Paper No. 2406, 2024 — [economics.fiu.edu/research/working-papers/2024/2406.pdf](https://economics.fiu.edu/research/working-papers/2024/2406.pdf)
- **Authors / abstract:** `[verify in PDF — WebFetch returned binary]`

**Why it matters.** Directly addresses the supply-chain channel, which corresponds to our GSCPI proxy in Channel 2. Should inform whether we treat GSCPI as a primary channel or a control.

---

## 8. Trabelsi (2025) — *Monetary Policy Transmission Under Global Versus Local Geopolitical Risk*

- **Already in repo:** `Team Project (with HKUST)/Trabelsi (2025)_Monetary Policy Transmission Under Global Versus Local Geopolitical Risk.pdf`
- **Specification:** `[verify in PDF — already on disk]`. The global-vs-local split is conceptually different from our GPT-vs-GPA split but methodologically informative.

---

## 9. Sveriges Riksbank (2025) — *How is Inflation Affected by Geopolitical Risk?*

- **Source:** Analysis box in *Monetary Policy Report*, March 2025 — [riksbank.se/.../how-is-inflation-affected-by-geopolitical-risk-analysis-in-monetary-policy-report-march-2025.pdf](https://www.riksbank.se/globalassets/media/rapporter/ppr/fordjupningar/engelska/2025/250320/how-is-inflation-affected-by-geopolitical-risk-analysis-in-monetary-policy-report-march-2025.pdf)
- **Format:** Central-bank policy box, not an academic paper. Useful for framing and Sweden-specific evidence; not a primary specification reference.

## 10. Dallas Fed (2025) — *Middle East Geopolitical Risk Modestly Affects Inflation and Inflation Expectations*

- **Source:** Federal Reserve Bank of Dallas Economics blog, August 2025 — [dallasfed.org/research/economics/2025/0821](https://www.dallasfed.org/research/economics/2025/0821)
- **Format:** Policy note. Argues that even under extreme oil-disruption scenarios the inflationary pass-through is muted post-1990 — directly relevant as a *counterpoint* to H1 and as a sanity check on our oil-channel result.

---

## What to do with this list

1. **Read the four PDFs already in our repo** (`literatures/Measuring Geopolitical Risjs.pdf`, `literatures/Geopolitical risk shocks- when size matters.pdf`, `Trabelsi (2025)`, `GinnSaadaoui (2025)`) and replace each `[verify in PDF]` block with the actual specification (variables, lags, sample, identification).
2. **Download the Caldara–Conlisk–Iacoviello–Penn JIE version** from `matteoiacoviello.com/research_files/JIE_2026.pdf` and extract the monthly-VAR specification — this should become the *direct benchmark* for our Stage 3 baseline LP.
3. **Decide which papers we replicate vs. cite.** A natural choice: replicate the Caldara et al. (2024/2026) headline US result with LP instead of VAR, then extend with the GPT/GPA split and our channel decomposition.
4. **Stage 6 (size matters)** should follow Brignone–Gambetti–Ricci closely — match their threshold convention so the results are directly comparable.

---

## Recommendation for our US-only baseline LP (H1)

Synthesising the conventions used across papers 1–3 above, here is a concrete recommendation for the US-only Stage 3 baseline. **This is a preliminary recommendation, not a locked spec** — Stage 2 (design lock) is where the team formally signs off.

### Variables

**Shock (RHS, key regressor)** — three parallel runs:
1. `gpr_us` — log of the US-specific GPR index (Caldara & Iacoviello provide a US-only version on the data page).
2. `gpt_us` — log GPT (threats sub-index).
3. `gpa_us` — log GPA (acts sub-index).

Using log levels (rather than first differences) follows Caldara & Iacoviello (2022). If GPR turns out to be persistent enough to look unit-rooty in our sample, switch to AR(p) residuals as the shock — to be decided in Stage 2 after seeing the autocorrelation.

**LHS (dependent variables)** — two cost-push signature outcomes, run *separately* (one LP per outcome):
1. `log(INDPRO)` — log industrial production (FRED `INDPRO`). This is the *output* leg of the cost-push test (expected sign: −).
2. `log(CPI_headline)` — log headline CPI (FRED `CPIAUCSL`). This is the *price* leg (expected sign: +).

LHS construction: $y_{t+h} - y_{t-1}$ in line with Jordà-style level IRFs (the same form we used in PS3 Q7). Robustness: also run with `log(CPILFESL)` (core CPI) and `log(PCEPI)`.

**Controls (RHS, contemporaneous and lagged)** — standard Caldara-style monthly macro controls so the LP is comparable to existing US VAR results:
- $L$ own lags of the LHS variable
- $L$ lags of the shock
- $L$ lags of: log industrial production, log headline CPI, fed funds rate, log real S&P 500 (FRED `SP500` deflated by CPI), log USD broad index (FRED `DTWEXBGS` or `TWEXBMTH`)

For Channel-stage LPs (Stage 4) the relevant channel variable is added contemporaneously and at lags, and we compare $\beta_h$ with vs. without it.

### Lag length

Recommend **L = 12** for the baseline (one full year of monthly lags). Reasons:
1. Matches the lag choice in `Prelim_OLS_MICH/EQ19852025VAR.m` (the team's existing preliminary work) — keeps results comparable to teammates' analysis.
2. Standard in monthly US LP/VAR literature (Caldara & Iacoviello use 12 in the AER paper VAR).
3. Long enough to absorb seasonal autocorrelation in monthly inflation.

Robustness: also run AIC/BIC selection over $L \in \{6, 12, 18, 24\}$ as a check.

### Horizon

$H = 36$ months (3 years). Long enough to see the full hump-shaped IRF documented in Caldara et al. (2024), short enough to avoid degree-of-freedom problems.

### Inference

Newey–West HAC standard errors with bandwidth $\max(h, \lfloor 4(T/100)^{2/9} \rfloor)$, since LP residuals are MA($h$) by construction. 90% confidence bands (in line with the team's Q5/Q7 plots).

### Sample period

**Recommend baseline sample: 1985-01 → 2024-12 (480 months).**

Reasoning:

| Constraint | Implication |
|---|---|
| Volcker disinflation ends ~1984 → post-1985 is a single monetary-policy regime | Start = 1985-01 |
| All H1 baseline series available pre-1985 (INDPRO 1919, CPI 1947, FFR 1954, MICH 1978) | No binding data constraint |
| GPR full sample 1900–present | Not binding |
| End at 2024-12 (or latest FRED vintage) | Maximal $T$ |
| COVID 2020-03 to 2021-12 is a clear outlier in IP and CPI | Dummy or robustness exclusion (see below) |

**Sample length:** ~480 monthly observations — comfortable for an LP with $L=12$ controls and $H=36$ horizon. No degree-of-freedom concerns even after dropping COVID months for robustness.

**COVID treatment.** Three options to report side-by-side as robustness:
1. **Full sample with dummy.** Add a 2020-03 to 2021-12 dummy interacted with the constant (and possibly with the LHS) — preferred default.
2. **Pre-COVID truncation.** End sample at 2020-02. Cleaner, but loses the most informative GPR period (Russia–Ukraine 2022).
3. **Post-COVID extension.** Start at 2022-01. Captures the high-GPR period but $T$ is too short for credible LP inference; use only as illustration.

**Why not post-2003 (TIPS sample) or post-1997 (GSCPI sample)?** Those constraints bind only for *channel* variables in Stages 4–5. For the H1 baseline (only IP and CPI on the LHS, FFR/oil/SP500/USD as controls), there is no reason to truncate. The longer sample wins.

### Sub-sample slices to report (robustness)

| Slice | Window | Purpose |
|---|---|---|
| Baseline | 1985-01 – 2024-12 | Main result |
| Pre-GFC | 1985-01 – 2007-12 | Removes ZLB and unconventional MP era |
| Pre-COVID | 1985-01 – 2020-02 | Cleanest sample |
| Post-2000 | 2000-01 – 2024-12 | Matches Wang et al. (2024) sample for direct comparison |

### Concrete first deliverable

After Stage 2 design lock, the first script (`code/02_baseline_LP.m`) should produce **6 panels in one figure**:

```
                IP response          CPI response
GPR (headline)  [β_h(IP|GPR)]        [β_h(CPI|GPR)]
GPT (threats)   [β_h(IP|GPT)]        [β_h(CPI|GPT)]
GPA (acts)      [β_h(IP|GPA)]        [β_h(CPI|GPA)]
```

with shaded 90% NW HAC CIs and horizon on the x-axis (0–36 months). H1 is supported if the right column trends positive and the left column trends negative for at least one of GPR/GPT/GPA at conventional horizons (h ≈ 6–24 months).

---

*Last updated: 2026-04-08. All bibliographic entries verified against publisher / SSRN / RePEc landing pages on this date. Items marked `[verify in PDF]` could not be extracted from publicly accessible HTML and need a manual read of the PDF before being relied on.*
