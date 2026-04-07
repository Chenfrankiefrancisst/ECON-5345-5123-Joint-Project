# Channel notes — GPR cost-push transmission

For each candidate channel: the mechanism, the proxy variable(s), expected sign, and identification/measurement caveats. To be filled in iteratively as the literature is read.

**Shock split.** Throughout, the analysis is run separately for **GPT (threats)** and **GPA (acts)**, the two sub-indices of Caldara & Iacoviello (2022). Prior expectation: GPT loads more on expectations / credit-spread channels; GPA loads more on physical commodity channels (oil, raw materials).

**Multiple proxies per channel.** A given channel can be measured several ways, and the choice is *not* innocuous — different proxies capture different aspects of the same economic mechanism. For instance, UMich's consumer-based 1-year expectation reflects household salience and media exposure, while SPF's professional 1-year forecast reflects model-based, smoothed expectations. Comparing them is itself informative: if GPR moves UMich much more than SPF, the channel runs through *household psychology* rather than *fundamentals*. Each proxy is therefore listed in the table below, and we plan to estimate the LP for **each variable separately** and contrast results.

---

## Master proxy table

| # | Channel | Variable | Series / code | Source | Frequency | Reference / rationale |
|---|---------|----------|---------------|--------|-----------|----------------------|
| **1. Oil & energy** ||||||
| 1.1 | Oil price (level) | WTI spot, USD/barrel | `DCOILWTICO` | FRED (EIA) | Daily → monthly | Hamilton (1983, 2003); benchmark US-side oil price |
| 1.2 | Oil price (level) | Brent spot, USD/barrel | `DCOILBRENTEU` | FRED (EIA) | Daily → monthly | Global benchmark; less affected by US storage frictions |
| 1.3 | Oil supply shock | Kilian oil supply shock | Kilian (2009) replication file | Kilian website | Monthly | Isolates supply-side innovations from demand; preferred for "cost-push" interpretation |
| 1.4 | Real oil price | Real WTI (deflated by US CPI) | constructed | own | Monthly | Removes nominal trend; comparable across long samples |
| 1.5 | Energy CPI sub-index | CPI: Energy commodities | `CUSR0000SACE` | BLS / FRED | Monthly | Direct pass-through to consumer prices |
| **2. Raw materials & commodities** ||||||
| 2.1 | Broad commodity index | Bloomberg Commodity Index (BCOM) | `BCOMTR` | Bloomberg | Daily → monthly | Diversified basket; standard in commodity-shock literature |
| 2.2 | Industrial metals | S&P GSCI Industrial Metals | `SPGSIN` | S&P / Bloomberg | Monthly | Closer to manufacturing input cost than aggregate BCOM |
| 2.3 | PPI: industrial commodities | `WPU03THRU15` | FRED (BLS) | Monthly | Producer-side measure; direct cost to US firms |
| 2.4 | PPI: all commodities | `PPIACO` | FRED (BLS) | Monthly | Headline cost-side index, longest sample |
| 2.5 | Shipping / freight | Baltic Dry Index | `BDIY` | Bloomberg | Monthly | Captures supply-chain disruption (real activity, not financial) |
| 2.6 | Global supply chain | NY Fed Global Supply Chain Pressure Index (GSCPI) | NY Fed | Monthly | Benigno et al. (2022); orthogonalised supply-chain measure |
| **3. Expected inflation** ||||||
| 3.1 | Household 1y E[π] | Michigan Consumer Survey | `MICH` | FRED (UMich) | Monthly | Salience / news-driven; sensitive to gas prices |
| 3.2 | Household 5y–10y E[π] | UMich 5–10y | `MICH5Y` (or table 32) | UMich | Monthly | Long-run anchoring measure |
| 3.3 | Professional 1y E[π] | SPF 1y CPI inflation | `EXPCPI1` | Philadelphia Fed SPF | Quarterly | Model-based, smoothed; anchored expectations of forecasters |
| 3.4 | Consumer 1y E[π] | NY Fed SCE | NY Fed SCE microdata | NY Fed | Monthly | Probabilistic, post-2013 only |
| 3.5 | Market 5y breakeven | TIPS 5y breakeven | `T5YIE` | FRED | Daily → monthly | Risk + liquidity premia confound, but available daily |
| 3.6 | Market 5y5y forward | 5y5y forward inflation | `T5YIFR` | FRED | Daily → monthly | Long-run market-implied anchoring |
| **4. Credit spread / financial conditions** ||||||
| 4.1 | Investment-grade spread | Moody's BAA – 10y Treasury | `BAA10Y` | FRED | Daily → monthly | Long sample; classic external finance premium |
| 4.2 | Quality spread | BAA – AAA | `BAA` − `AAA` | FRED | Monthly | Removes Treasury term-premium movements |
| 4.3 | GZ spread | Gilchrist–Zakrajšek spread | replication file | author website | Monthly | Constructed from individual bonds; cleaner micro-foundation |
| 4.4 | Excess bond premium | EBP | replication file | author website | Monthly | Residual after stripping default risk; risk-bearing capacity proxy |
| 4.5 | High-yield spread | ICE BofA US HY OAS | `BAMLH0A0HYM2` | FRED | Daily → monthly | More sensitive to risk repricing |
| 4.6 | Financial conditions | Chicago Fed NFCI | `NFCI` | FRED (Chicago Fed) | Weekly → monthly | Composite; covers credit + leverage + risk |

---

## Channel-by-channel notes

### 1. Oil & energy
- **Mechanism.** GPR (esp. Middle-East / Russia events) raises oil prices via supply risk premia and precautionary demand. Higher oil → higher input cost → higher headline & core CPI; output contracts (Hamilton 1983, Kilian 2009).
- **Why multiple proxies?** WTI is US-centric, Brent is global — divergence (e.g. 2011–14) is informative. Kilian's *supply* shock isolates the cost-push interpretation from demand-driven oil moves. Energy CPI sub-index measures pass-through directly.
- **Expected sign.** Channel response to GPR: **+**. Inflation response with oil controlled: **attenuated**.
- **Caveats.** Oil prices reflect both supply and demand — recursive ordering with GPR first is the cleanest baseline; supply-shock proxies (Kilian, Baumeister–Hamilton) for robustness.

### 2. Raw materials & commodities
- **Mechanism.** Beyond oil, broad commodities (metals, agricultural inputs, freight) propagate GPR shocks through global supply chains.
- **Why multiple proxies?** BCOM is a diversified basket; GSCI Industrial Metals zooms into manufacturing inputs; PPI series measure US producer-side prices; Baltic Dry / GSCPI measure *physical* supply-chain stress orthogonal to commodity prices. Each isolates a different sub-mechanism.
- **Expected sign.** Channel response: **+**. Attenuation of inflation response: moderate.
- **Caveats.** Most commodity indices are USD-denominated → mechanically correlated with USD movements. GSCPI starts in 1997.

### 3. Expected inflation
- **Mechanism.** GPR raises households' and firms' inflation expectations (uncertainty + salience), which feeds back into wage/price setting.
- **Why multiple proxies?**
  - **UMich vs. SPF.** UMich is consumer-based and reacts strongly to gas prices and news exposure → sensitive to *salience* of geopolitical events. SPF is professional, smoothed, and reflects *model-based* expectations. A wedge between UMich and SPF responses to GPR would tell us the channel runs through household perception, not fundamentals.
  - **Short vs. long horizon.** 1y measures react to current shocks; 5y/5y5y measure anchoring. If GPR moves only short-horizon expectations, the channel is transitory.
  - **Survey vs. market.** TIPS breakevens are daily and forward-looking but contain liquidity/risk premia — useful for high-frequency identification but noisier as expectation measures.
- **Expected sign.** Channel response: **+**. Attenuation: substantial if expectations channel is dominant.
- **Caveats.** SPF is quarterly — needs interpolation or quarterly LP. NY Fed SCE post-2013 only.

### 4. Credit spread / financial conditions
- **Mechanism.** GPR raises perceived default risk → corporate bond spreads widen → external finance premium ↑ → firms cut investment & raise prices to preserve margins (Gilchrist–Zakrajšek 2012).
- **Why multiple proxies?** BAA-10y is the textbook spread (long sample); BAA-AAA strips Treasury movements; GZ/EBP separate default risk from risk-bearing capacity (the EBP is the residual the literature treats as the true financial-shock proxy); HY OAS is more sensitive to repricing; NFCI is a composite covering more than just credit.
- **Expected sign.** Channel response: **+**. This channel is more "demand-side" — would dampen output more than inflation, so a *strong* response here would weaken the cost-push interpretation in favour of a demand channel. Important to test as a horse-race.
- **Caveats.** GZ/EBP available 1973–. NFCI is weekly. HY OAS starts 1997.

---

## Cross-channel notes

- **Ordering for LP controls.** When testing channel attenuation, include the channel variable contemporaneously and at lags. The size of $\beta_h$ in the controlled vs. uncontrolled regression gives the share absorbed by the channel.
- **Multiple proxies → robustness, not p-hacking.** The plan is to **report all proxy variants per channel** rather than cherry-pick. Disagreement across proxies is a finding, not a failure.
- **Identification scheme.** Two routes:
  1. *Recursive:* GPR/GPT/GPA ordered first (plausibly exogenous to US monthly macro).
  2. *External instrument:* use the Caldara–Iacoviello narrative GPR shock series.
- **Sign asymmetry.** Caldara et al. (2024) document asymmetric responses to GPR-up vs. GPR-down events — worth checking with state-dependent LP.

---

## References

- Baumeister, C. & Hamilton, J.D. (2019). "Structural Interpretation of Vector Autoregressions with Incomplete Identification." *AER.*
- Benigno, G. et al. (2022). "A New Barometer of Global Supply Chain Pressures." *NY Fed Liberty Street Economics.*
- Caldara, D. & Iacoviello, M. (2022). "Measuring Geopolitical Risk." *AER.*
- Caldara, D., Conlisk, S., Iacoviello, M. & Penn, M. (2024). "Do Geopolitical Risks Raise or Lower Inflation?"
- Gilchrist, S. & Zakrajšek, E. (2012). "Credit Spreads and Business Cycle Fluctuations." *AER.*
- Hamilton, J.D. (1983). "Oil and the Macroeconomy since World War II." *JPE.*
- Hamilton, J.D. (2003). "What Is an Oil Shock?" *J. Econometrics.*
- Kilian, L. (2009). "Not All Oil Price Shocks Are Alike." *AER.*
