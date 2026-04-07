# Meeting / feedback log

## 2026-04-?? — Prof. Baek (brainstorming feedback)

**Direction.**

1. First check whether GPR shocks act as a **cost-push** disturbance (inflation ↑, output ↓).
2. If yes, decompose into transmission **channels** — examples: oil price, expected inflation, raw materials, credit spread.
3. Identify which channel is **dominant**.
4. *Time permitting*, link the cost-push result to the **Fed's interest-rate decision / Taylor rule** as a follow-up — but **do not start there**.

**Why this step-by-step structure?** Two reasons Prof. Baek emphasised:

- **Endogeneity in single-equation OLS.** A naive OLS regression of inflation (or the policy rate) on GPR is contaminated by simultaneity and omitted-variable bias — GPR co-moves with oil, expectations, and the business cycle, all of which independently drive inflation and Fed decisions. We need an identification strategy that isolates the GPR shock first, before layering on more endogenous variables.
- **Taylor rule estimation is hard on its own.** Estimating a Taylor rule (let alone an *augmented* one with GPR) is a notoriously difficult exercise — issues of real-time data, forward-looking expectations, regime changes, weak identification of the inflation/output coefficients. Bolting it onto an unsettled cost-push question would compound both problems.

**Implication for the plan.** Lock in the cost-push result first using a clean LP design (Stages 3–5). Treat the Fed-response / Taylor-rule extension (Stage 6) as **optional** — pursue only if Stages 3–5 give a credible cost-push finding and time remains.

**Methodological steer.** Use **Local Projections** (Jordà 2005) as the main estimator. More flexible than VAR for channel-by-channel analysis, easy to extend to nonlinear / state-dependent settings, and the horizon-by-horizon structure makes it natural to add or drop channels without re-specifying a whole system.

**My next steps.**
- Read Caldara–Iacoviello (2022, 2024) carefully.
- Decide on shock construction (raw GPR vs. narrative shock series).
- Lock baseline LP specification before estimating anything.
