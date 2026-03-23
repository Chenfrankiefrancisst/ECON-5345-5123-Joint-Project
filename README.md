# ECON 5345 & 5123 Joint Project

**Team Members:** Frankie CHEN (HKUST), Nayeong KANG (SKKU), Bomi YUN (SKKU)

**Supervisors:** Professors Byoungchan LEE (HKUST), Chaewon BAEK (SKKU, Tufts)

* `SVAR.zip`: Estimation of geopolitical risks to macro variables in Structural VAR.
* `csvtom.m`: transfers a `.csv` to `.m`


# Brainstorming Ideas

# Extending the Honors Thesis to Monetary Policy: Phillips Curve and Taylor-Rule Gap under Geopolitical Risk

## Big picture

The main extension is not just to “add monetary policy” to the existing thesis. The stronger idea is:

> Geopolitical shocks, especially **threat shocks**, may alter both  
> 1. the **inflation process** (for example, the slope of the Phillips curve), and  
> 2. the **monetary policy reaction function** (so that policy responds more strongly than a simple Taylor rule based on current inflation and activity would imply).

This turns the thesis into a richer macro-finance / monetary-policy project.

---

## 1. Core observation from the existing thesis

From the current IRFs, the broad pattern appears to be:

- **Threat shocks** generate:
  - stronger increases in CPI
  - stronger increases in the shadow policy rate
  - stronger increases in the 1-year yield
  - tighter financial conditions
- **Act shocks** are less inflationary and tend to generate a weaker policy response.

A key puzzle is:

$$
\Delta r_t > \text{what a simple Taylor rule would predict from } \Delta \pi_t
$$

In words: the policy rate response seems more volatile or more aggressive than the increase in inflation alone would imply.

This is especially interesting for **threat shocks**.

---

## 2. How to frame the monetary-policy puzzle

Do **not** immediately call this “policy overreaction.”

A better framing is:

> The observed policy response appears stronger than can be rationalized by a simple contemporaneous Taylor rule based only on current inflation and current activity.

This matters because the larger response of \( r_t \) may reflect several things:

- the central bank reacting to **expected future inflation**, not just current CPI
- response to **oil / commodity pass-through**
- response to **financial conditions deterioration**
- response to **inflation tail risk / credibility concerns**
- response to **geopolitical risk directly**
- measurement features of the **shadow rate** itself

So the empirical task is to distinguish between:

1. a **systematic and rational** policy reaction to broader risks, versus  
2. a genuine **excess monetary tightening shock** beyond fundamentals.

---

## 3. Should the project use Kalman filter?

### Short answer

- **No**, not necessarily for the first pass.
- **Yes**, if the goal is to estimate **time-varying coefficients**.

### Case A: fixed-slope Phillips curve
If the Phillips curve is estimated as a constant-parameter equation, then Kalman filter is not necessary.

For example:

$$
\pi_t = \alpha + \kappa x_t + \gamma g_t + \varepsilon_t
$$

where:
- \( \pi_t \) = inflation
- \( x_t \) = slack / output gap / unemployment gap / marginal cost
- \( g_t \) = geopolitical risk shock

This can be estimated with ordinary reduced-form methods.

### Case B: time-varying Phillips slope
If the question is:

> Does the slope of the Phillips curve change under geopolitical stress?

then Kalman filter becomes useful.

For example:

$$
\pi_t = \alpha_t + \kappa_t x_t + \gamma_t g_t + \varepsilon_t
$$

with state evolution:

$$
\alpha_t = \alpha_{t-1} + \nu_t^\alpha,\qquad
\kappa_t = \kappa_{t-1} + \nu_t^\kappa,\qquad
\gamma_t = \gamma_{t-1} + \nu_t^\gamma
$$

This is a state-space model, and Kalman filter is the natural tool.

### Recommendation
For the project, start **without** Kalman filter. Begin with interaction models. Add TVP/Kalman only later if the evidence is strong and the time-varying interpretation becomes central.

---

## 4. How to study the Phillips curve under geopolitical shocks

A clean baseline is an interaction specification:

$$
\pi_t
=
\alpha
+
\kappa x_t
+
\gamma g_t
+
\delta (x_t \times g_t)
+
\varepsilon_t
$$

Interpretation:

- \( \kappa \): baseline Phillips curve slope
- \( \delta \): how geopolitical shocks change the slope

Then:

- if \( \delta > 0 \), the Phillips curve becomes **steeper** under geopolitical risk
- if \( \delta < 0 \), the Phillips curve becomes **flatter**

A more refined version separates **threat** and **act** shocks:

$$
\pi_t
=
\alpha
+
\kappa x_t
+
\gamma_1 g_t^{threat}
+
\gamma_2 g_t^{act}
+
\delta_1 (x_t \times g_t^{threat})
+
\delta_2 (x_t \times g_t^{act})
+
\varepsilon_t
$$

This is probably the best first empirical design.

### Economic interpretation
Under geopolitical threat shocks, inflation may become less demand-driven and more supply-risk-driven:

- oil prices rise
- imported inputs become more costly
- shipping and trade risk increase
- firms may widen markups under uncertainty
- expectations of future shortages rise

So the empirical Phillips relation between inflation and slack may either:

- become **steeper**, if supply pressure reinforces inflation,
- or appear **flatter**, if inflation becomes more driven by exogenous cost-push forces rather than domestic slack.

That is an empirical question.

---

## 5. Why the policy response may exceed what a simple Taylor rule implies

The observed pattern:

$$
\Delta r_t > \phi_\pi \Delta \pi_t + \phi_x \Delta x_t
$$

does not automatically imply an irrational central bank.

It may simply imply that the rule is incomplete.

### A richer interpretation
Under geopolitical threat shocks, the central bank may respond to:

- **expected inflation**
- **oil and commodity-price risk**
- **financial conditions**
- **tail risk to inflation**
- **de-anchoring concerns**
- **geopolitical risk directly**

A more realistic policy rule is therefore:

$$
r_t
=
\rho r_{t-1}
+
(1-\rho)\left(
\phi_\pi E_t\pi_{t+h}
+
\phi_x x_t
+
\phi_g g_t
\right)
+
u_t
$$

where \( \phi_g > 0 \) is possible, especially for **threat shocks**.

This would explain why the rate response is stronger than current CPI alone would suggest.

---

## 6. Important measurement issue: shadow rate vs actual policy rate

The thesis uses the **shadow rate**, which is informative but must be handled carefully.

The shadow rate differs from the observed federal funds rate because it is inferred from the yield curve and can reflect:

- the expected future path of policy
- term-structure repricing
- lower-bound regime effects
- broader financial-market expectations

So if:

$$
\Delta \text{ShadowRate}_t \gg \Delta \pi_t
$$

this may reflect not only actual policy moves, but also a repricing of the expected path of monetary policy.

### Recommendation
For the monetary-policy extension, compare several indicators:

- actual federal funds rate or target rate
- shadow rate
- 1-year yield
- 2-year yield
- high-frequency monetary policy surprise series, if available

If all of them show the same “too strong” response, the puzzle is likely real.  
If the pattern is concentrated in the shadow rate, then part of the puzzle may be measurement-related.

---

## 7. A clean empirical strategy for the Taylor-rule gap

### Step 1: estimate a baseline Taylor rule

$$
r_t = \rho r_{t-1} + (1-\rho)(\phi_\pi \pi_t + \phi_x x_t) + \varepsilon_t^r
$$

where:
- \( r_t \) = policy rate or shadow rate
- \( \pi_t \) = inflation
- \( x_t \) = output gap / unemployment gap / activity measure

Then define the fitted residual:

$$
\widehat{u}_t^{TR}
=
r_t - \widehat{r}_t^{Taylor}
$$

This residual captures the part of the policy move not explained by the standard Taylor rule.

### Step 2: relate the Taylor-rule residual to geopolitical shocks

$$
\widehat{u}_t^{TR}
=
a
+
b_1 g_t^{threat}
+
b_2 g_t^{act}
+
e_t
$$

Interpretation:

- if \( b_1 > 0 \), then **threat shocks** are associated with a policy response stronger than the standard Taylor rule predicts
- if \( b_2 \) is small or negative, then act shocks do not generate the same “excess” tightening

This is a clean way to formalize the visual IRF puzzle.

### Step 3: estimate an augmented Taylor rule

$$
r_t
=
\rho r_{t-1}
+
(1-\rho)\left(
\phi_\pi \pi_t
+
\phi_x x_t
+
\phi_{th} g_t^{threat}
+
\phi_{act} g_t^{act}
\right)
+
u_t
$$

Possible interpretation:

- \( \phi_{th} > 0 \): the central bank responds directly to threat shocks
- \( \phi_{act} \) may be smaller or negative

If the standard Taylor residual shrinks a lot in this augmented specification, then the earlier “excess response” is not true overreaction. It is a systematic response to omitted risk factors.

---

## 8. Forward-looking Taylor rule: probably the most important extension

Since geopolitical threats are largely about expectations, a forward-looking rule may be more appropriate:

$$
r_t
=
\rho r_{t-1}
+
(1-\rho)\left(
\phi_\pi E_t \pi_{t+h}
+
\phi_x x_t
+
\phi_g g_t
\right)
+
u_t
$$

This matters because policymakers often respond to future inflation risk rather than current observed CPI.

If the puzzle disappears or weakens when expected inflation is used instead of current inflation, then the interpretation is:

> The central bank is reacting to inflation risk embedded in geopolitical threats, not simply to current CPI.

That would be a strong and convincing result.

---

## 9. A useful decomposition of the policy-rate response

One strong contribution is to decompose the policy-rate response into components:

$$
\Delta r_t
=
\underbrace{\phi_\pi \Delta \pi_t}_{\text{inflation term}}
+
\underbrace{\phi_x \Delta x_t}_{\text{activity term}}
+
\underbrace{\phi_g g_t}_{\text{direct geopolitical term}}
+
\underbrace{\xi_t}_{\text{residual / policy shock}}
$$

Then, after a threat shock, ask:

- how much of the increase in \( r_t \) is explained by inflation?
- how much by activity?
- how much by direct geopolitical response?
- how much is left as unexplained residual?

This turns the IRF comparison into a formal quantitative result.

---

## 10. Systematic policy response vs true monetary shock

This distinction is crucial.

When the rate rises strongly after a threat shock, two interpretations are possible:

### Case 1: systematic policy response
The central bank intentionally reacts to geopolitical threats as part of its reaction function.

### Case 2: true exogenous monetary-policy shock
The central bank tightens more than fundamentals justify.

Empirically, the way to separate these is:

1. estimate the augmented policy rule
2. treat the remaining residual as the possible monetary-policy shock
3. test whether that residual still rises after threat shocks

If it does, then there may be genuine over-tightening or hawkish policy shocks.  
If it does not, then the larger rate response is systematic and explainable.

---

## 11. Recommended order of implementation

The cleanest sequence is:

### Stage 1: policy variables
Compare:
- actual policy rate
- shadow rate
- short yields (1-year, 2-year)

### Stage 2: Phillips-curve extension
Estimate interaction models:

$$
\pi_t
=
\alpha
+
\kappa x_t
+
\gamma_1 g_t^{threat}
+
\gamma_2 g_t^{act}
+
\delta_1 (x_t \times g_t^{threat})
+
\delta_2 (x_t \times g_t^{act})
+
\varepsilon_t
$$

### Stage 3: baseline Taylor rule
Estimate:

$$
r_t = \rho r_{t-1} + (1-\rho)(\phi_\pi \pi_t + \phi_x x_t) + \varepsilon_t^r
$$

and compute the Taylor-rule gap:

$$
\widehat{u}_t^{TR}
=
r_t - \widehat{r}_t^{Taylor}
$$

### Stage 4: explain the Taylor-rule gap
Regress the gap on geopolitical shocks:

$$
\widehat{u}_t^{TR}
=
a
+
b_1 g_t^{threat}
+
b_2 g_t^{act}
+
e_t
$$

### Stage 5: augmented and forward-looking rules
Estimate:

$$
r_t
=
\rho r_{t-1}
+
(1-\rho)\left(
\phi_\pi E_t\pi_{t+h}
+
\phi_x x_t
+
\phi_{th} g_t^{threat}
+
\phi_{act} g_t^{act}
\right)
+
u_t
$$

### Stage 6: only then consider TVP/Kalman
If needed, estimate a time-varying policy rule:

$$
r_t
=
\rho_t r_{t-1}
+
(1-\rho_t)\left(
\phi_{\pi,t}\pi_t
+
\phi_{x,t}x_t
+
\phi_{g,t}g_t
\right)
+
\varepsilon_t
$$

with time-varying parameters estimated in state-space form.

---

## 12. How to write the main interpretation

A good substantive interpretation is:

> Threat-type geopolitical shocks are not merely current inflation shocks. They are inflation-risk shocks. They raise expected future inflation, commodity-price risk, and the danger of de-anchoring expectations. As a result, monetary policy may tighten more strongly than a simple contemporaneous Taylor rule based only on current CPI and activity would suggest.

Meanwhile:

> Act-type shocks appear more recessionary and less inflationary, so the policy response is weaker and may not show the same Taylor-rule gap.

This gives a coherent explanation of why the rate response may look more volatile than inflation in the IRFs.

---

## 13. Final recommendation

Do **not** begin with Kalman filter.

Begin with:

1. an interaction Phillips curve  
2. a baseline Taylor rule  
3. a Taylor-rule residual / gap decomposition  
4. an augmented forward-looking Taylor rule with threat and act shocks

Then add TVP/Kalman only if the project later needs a time-varying parameter interpretation.

That is the cleanest and most defensible extension from the current thesis.
