#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Stage 1 — Data download for the GPR cost-push project
#
# Pulls every series that is publicly accessible without an API key.
# Outputs go to ../data/raw/ as CSV/XLSX with descriptive filenames.
# Manual-only sources are listed at the bottom.
# ---------------------------------------------------------------------------

set -e
cd "$(dirname "$0")/../data/raw"

CURL="curl -sSL --fail --retry 3 --retry-delay 2"

echo "=== FRED series (CSV) ==="
declare -A FRED=(
  # Macro core
  [INDPRO]="industrial_production"
  [CPIAUCSL]="cpi_all_urban"
  [CPILFESL]="cpi_core"
  [PCEPI]="pce_price_index"
  [FEDFUNDS]="fed_funds_rate"
  [UNRATE]="unemployment_rate"
  # Oil & energy
  [DCOILWTICO]="oil_wti"
  [DCOILBRENTEU]="oil_brent"
  [CUSR0000SACE]="cpi_energy_commodities"
  # Commodities / PPI
  [PPIACO]="ppi_all_commodities"
  [WPSID61]="ppi_industrial_commodities"
  # Expected inflation
  [MICH]="umich_expinf_1y"
  [T5YIE]="tips_breakeven_5y"
  [T5YIFR]="tips_5y5y_forward"
  # Credit / financial
  [BAA10Y]="spread_baa_10y"
  [BAA]="moody_baa_yield"
  [AAA]="moody_aaa_yield"
  [BAMLH0A0HYM2]="hy_oas"
  [NFCI]="chicago_fed_nfci"
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
  && echo "  ok  GPR/GPT/GPA" || echo "  FAIL GPR — fetch manually from matteoiacoviello.com"

echo
echo "=== NY Fed Global Supply Chain Pressure Index (xlsx) ==="
$CURL -o "gscpi_nyfed.xlsx" \
  "https://www.newyorkfed.org/medialibrary/research/interactives/gscpi/downloads/gscpi_data.xlsx" \
  && echo "  ok  GSCPI" || echo "  FAIL GSCPI"

echo
echo "=== Gilchrist–Zakrajšek EBP (csv) ==="
$CURL -o "ebp_gz_federalreserve.csv" \
  "https://www.federalreserve.gov/econresdata/notes/feds-notes/2016/files/ebp_csv.csv" \
  && echo "  ok  EBP/GZ" || echo "  FAIL EBP — fetch manually from federalreserve.gov FEDS Notes"

echo
echo "=== SPF inflation forecasts (xlsx) ==="
$CURL -o "spf_inflation.xlsx" \
  "https://www.philadelphiafed.org/-/media/frbp/assets/surveys-and-data/survey-of-professional-forecasters/data-files/files/inflation.xlsx" \
  && echo "  ok  SPF" || echo "  FAIL SPF — fetch manually from philadelphiafed.org"

echo
echo "=== DONE ==="
echo
echo "Manual-only sources (not downloaded):"
echo "  - Kilian (2009) oil supply shock series       https://sites.google.com/site/lkilian2019/research"
echo "  - Bloomberg BCOM, GSCI Industrial Metals      Bloomberg terminal (subscription)"
echo "  - Baltic Dry Index                            Bloomberg terminal"
echo "  - NY Fed Survey of Consumer Expectations      https://www.newyorkfed.org/microeconomics/sce"
echo "  - Caldara–Iacoviello narrative shock series   https://www.matteoiacoviello.com/gpr.htm (Excel)"
