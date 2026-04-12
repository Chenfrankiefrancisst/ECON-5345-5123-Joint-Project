#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# H1 Baseline — Data download (GPR cost-push signature)
#
# Downloads series needed for H1 baseline + robustness:
#   Shock:       GPR / GPT / GPA  (Caldara & Iacoviello)
#   Outcome:     INDPRO, CPIAUCSL
#   Robustness:  UNRATE, VIXCLS
#   Stage 4+:    FEDFUNDS, DCOILWTICO (kept for future channel analysis)
#
# Usage:  bash download_data.sh
# Output: ../data/raw/<descriptive_name>__<FRED_code>.csv
# ---------------------------------------------------------------------------

set -e
cd "$(dirname "$0")/../data/raw"

CURL="curl -sSL --fail --retry 3 --retry-delay 2"

echo "=== FRED series (CSV) ==="
declare -A FRED=(
  # Outcome
  [INDPRO]="industrial_production"
  [CPIAUCSL]="cpi_all_urban"
  # Robustness controls
  [UNRATE]="unemployment_rate"
  [VIXCLS]="vix_daily"
  # Stage 4+ (channel analysis)
  [FEDFUNDS]="fed_funds_rate"
  [DCOILWTICO]="oil_wti"
)

for code in "${!FRED[@]}"; do
  out="${FRED[$code]}__${code}.csv"
  if $CURL -o "$out" "https://fred.stlouisfed.org/graph/fredgraph.csv?id=${code}"; then
    echo "  ok  $code -> $out"
  else
    echo "  FAIL $code"
  fi
done

echo
echo "=== Caldara & Iacoviello GPR (xls) ==="
$CURL -o "gpr_caldara_iacoviello.xls" \
  "https://www.matteoiacoviello.com/gpr_files/data_gpr_export.xls" \
  && echo "  ok  GPR/GPT/GPA" || echo "  FAIL GPR — fetch manually from matteoiacoviello.com/gpr.htm"

echo
echo "=== DONE ==="
echo "Files saved to: $(pwd)"
