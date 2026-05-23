# GPR Shock Analysis: Local Projection with Poisson Residualization

> **Last Updated:** 2026.05.23  
> **Status:** Work in Progress

Geopolitical Risk (GPR) shock 추출 및 Local Projection 분석을 위한 MATLAB 코드입니다.

## Overview

```
AR_GPR_shock.m          # Step 1: GPR shock 추출
        ↓
Plot_GPR_shock.m        # (Optional) Shock 시각화
        ↓
LP_baseline.m           # Step 2a: Baseline LP 분석
LP_Poisson.m            # Step 2b: Poisson-residualized LP 분석
Poisson_shock_test.m    # Step 2c: Poisson shock 진단 테스트
```

## File Descriptions

### 1. `AR_GPR_shock.m`
**GPR shock 추출 및 진단 테스트**

AR(4) 모형으로 GPR 지수에서 예측 불가능한 혁신(innovation)을 추출합니다.

**모형:**
```
GPR_t = α + Σρ_j GPR_{t-j} + ξ'[Unemp_t, FFR_t] + ω'[Oil]_{t-1} + u_t
z_t = (u_t - mean(u)) / sd(u)
```

**두 가지 변형:**
- `with_oil`: lag-1 유가(Brent, WTI, Gasoline) 통제 포함
- `without_oil`: 유가 통제 제외

**진단 테스트:**
- Granger exogeneity test (거시변수 → shock)
- Ljung-Box Q test (white noise)
- Breusch-Godfrey LM test (serial correlation)

**출력:** `GPR_shock_output/`

---

### 2. `Plot_GPR_shock.m`
**GPR shock 시계열 시각화**

추출된 GPR shock (z_t)을 주요 지정학적 이벤트와 함께 시각화합니다.

**특징:**
- World, GPT (Threats), GPA (Acts) 3개 shock 비교
- with_oil vs without_oil 오버레이
- 주요 이벤트 수직선 표시 (9/11, Iraq War, Crimea, Ukraine 등)

**출력:** `GPR_shock_output/z_shocks_timeseries.{png,fig}`

---

### 3. `LP_baseline.m`
**Baseline Local Projection 분석**

GPR shock이 유가 및 거시변수에 미치는 동태적 효과를 추정합니다.

**추정 모형:**
```
y_{t+h} - y_{t-1} = α + β·z_t + controls + ε_{t+h}
```

**특징:**
- Newey-West HAC 표준오차 (bandwidth = h+1)
- 12분기 horizon IRF
- with_oil vs without_oil 비교 대시보드

**출력:** `LP_baseline_output/`

---

### 4. `LP_Poisson.m`
**Poisson-Residualized Local Projection 분석**

이벤트 도착(event arrival)을 Poisson 과정으로 모형화하고, 잔차를 LP에 사용합니다.

**Step 1:** `AR_GPR_shock.m` 출력에서 GPR shock 로드

**Step 2:** Poisson event-arrival 잔차화
```
N_t^k ~ Poisson(λ_t^k)
log(λ_t^k) = α + β·z_t^{GPR} + controls
z_t^{N,k} = (N_t - λ_t) / sqrt(λ_t)  (Pearson residual, standardized)
```

**Step 3:** LP 추정 (두 가지 변형)
- (a) Poisson 잔차 사용: `y_{t+h} - y_{t-1} = α + β·z_t^{N,k} + ...`
- (b) 원시 이벤트 카운트 사용: `y_{t+h} - y_{t-1} = α + β·N_t^k + ...`

**Step 4:** (a) vs (b) 오버레이 대시보드

**출력:** `LP_Poisson_output/`

---

### 5. `Poisson_shock_test.m`
**Poisson Event-Arrival Shock 진단 테스트**

Poisson 잔차화된 이벤트 shock에 대한 진단을 수행합니다.

**분석 대상 이벤트:**
- Chokepoint shipping risk onset
- Strict supply disruption onset
- Energy sanction onset

**진단 테스트:**
- Conditional Granger exogeneity (manual OLS F-test)
- Ljung-Box Q white-noise test
- Breusch-Godfrey LM test

**시각화:**
- 원시 도착 N_t^k와 Poisson shock z_t^{N,k} 비교
- Oil-specific 지정학적 에피소드 타임라인

**출력:** `Poisson_shock_tests_output/`

---

## Data Requirements

**필수 파일:**
- `Q_Levels_Database.csv` - 분기별 거시경제 데이터
- `oil_relevant_gpr_event_dummies_extended_onset_realized_1986Q1_2025Q4.csv` - 이벤트 더미

## Execution Order

```matlab
% Step 1: GPR shock 추출 (필수, 먼저 실행)
run('AR_GPR_shock.m')

% Step 2: 시각화 (선택)
run('Plot_GPR_shock.m')

% Step 3: LP 분석 (원하는 것 선택)
run('LP_baseline.m')      % Baseline LP
run('LP_Poisson.m')       % Poisson-residualized LP
run('Poisson_shock_test.m')  % Poisson shock 진단
```

## Output Structure

```
GPR_shock_output/
├── gpr_shocks.csv                 # 추출된 shock 시계열
├── gpr_shock_diagnostics.csv      # 추출 진단 (R², nobs)
├── granger_exog_test.csv          # Granger 검정 결과
├── white_noise_lbq.csv            # Ljung-Box Q 검정
├── white_noise_bg.csv             # Breusch-Godfrey 검정
├── workspace_gpr_shock.mat        # 전체 workspace 저장
└── z_shocks_timeseries.{png,fig}  # Shock 시각화

LP_baseline_output/
├── IRF_compare_*.{png,fig}        # IRF 비교 그래프
└── workspace_lp.mat               # LP 결과 workspace

LP_Poisson_output/
├── overlay_*.{png,fig}            # Poisson vs Raw 비교
└── gpr_diagnostics_*.csv          # 진단 결과

Poisson_shock_tests_output/
├── poisson_shock_diagnostics.csv  # Poisson 모형 진단
├── poisson_shock_granger_exog.csv # Granger 검정
├── poisson_shock_white_noise_*.csv # White noise 검정
├── poisson_event_shocks.csv       # 이벤트 shock 시계열
└── event_arrivals_and_poisson_shocks_*.{png,fig}  # 시각화
```

## Requirements

- MATLAB R2020a or later
- Statistics and Machine Learning Toolbox (for `glmfit`, `lbqtest`)
- Econometrics Toolbox (optional, for `gctest`)

## References

- Caldara, D., & Iacoviello, M. (2022). Measuring Geopolitical Risk. *American Economic Review*.
- Jordà, Ò. (2005). Estimation and Inference of Impulse Responses by Local Projections. *American Economic Review*.
