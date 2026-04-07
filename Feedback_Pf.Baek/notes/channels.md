# Channel notes — GPR cost-push transmission

For each candidate channel: the mechanism, the proxy variable(s), expected sign, and identification/measurement caveats. To be filled in iteratively as the literature is read.

**Shock split.** Throughout, the analysis is run separately for **GPT (threats)** and **GPA (acts)**, the two sub-indices of Caldara & Iacoviello (2022). Prior expectation: GPT loads more on expectations / credit-spread channels; GPA loads more on physical commodity channels (oil, raw materials).

---

## 1. Oil price

- **Mechanism.** GPR (esp. Middle-East / Russia events) raises oil prices via supply risk premia and precautionary demand. Higher oil → higher input cost → higher headline & core CPI; output contracts (Hamilton 1983, Kilian 2009).
- **Proxy.** WTI spot, Brent spot, oil supply/demand shock decomposition (Kilian 2009; Baumeister & Hamilton 2019).
- **Expected sign.** Channel response to GPR: **+**. Inflation response with oil controlled: **attenuated**.
- **Caveats.** Oil prices reflect both supply and demand — need to isolate the supply component to argue it is "cost-push".

## 2. Raw materials / commodities

- **Mechanism.** Beyond oil, broad commodities (metals, agricultural inputs, freight) propagate GPR shocks through global supply chains.
- **Proxy.** PPI commodity sub-indices, BCOM index, Baltic Dry Index for shipping.
- **Expected sign.** Channel response: **+**. Attenuation of inflation response: moderate.
- **Caveats.** Many commodity indices are dollar-denominated → mechanically correlated with USD movements.

## 3. Expected inflation

- **Mechanism.** GPR raises households' and firms' inflation expectations (uncertainty + salience), which feeds back into wage/price setting.
- **Proxy.** Michigan 1y E[π] (`MICH`), FRBNY SCE 1y, TIPS breakeven 5y.
- **Expected sign.** Channel response: **+**. Attenuation: substantial if expectations channel is dominant.
- **Caveats.** Survey vs. market measures diverge in stress periods. Michigan E[π] is noisy.

## 4. Credit spread

- **Mechanism.** GPR raises perceived default risk → corporate bond spreads widen → external finance premium ↑ → firms cut investment & raise prices to preserve margins (Gilchrist–Zakrajšek 2012).
- **Proxy.** BAA-AAA spread, GZ spread, excess bond premium (EBP).
- **Expected sign.** Channel response: **+**. This channel is more "demand-side" — would dampen output more than inflation.
- **Caveats.** GZ/EBP series start in 1973; sample limitation if joined with monthly GPR.

---

## Cross-channel notes

- **Ordering for LP controls.** When testing channel attenuation, include the channel variable contemporaneously and at lags. The size of $\beta_h$ in the controlled vs. uncontrolled regression gives the share absorbed by the channel.
- **Identification scheme.** Two routes:
  1. *Recursive:* GPR ordered first (plausibly exogenous to US monthly macro).
  2. *External instrument:* use the Caldara–Iacoviello narrative GPR shock series.
- **Sign asymmetry.** Caldara et al. (2024) document asymmetric responses to GPR-up vs. GPR-down events — worth checking with state-dependent LP.
