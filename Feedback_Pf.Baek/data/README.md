# Data — Stage 1 inventory

All raw files live in `raw/`. Re-download by running `../scripts/download_data.sh` from this folder's parent. The script is idempotent — re-running overwrites with the latest vintage.

## Auto-downloaded (public)

| File | Series / source | Coverage | Freq | Notes |
|------|----------------|----------|------|-------|
| `industrial_production__INDPRO.csv` | FRED INDPRO | 1919-01– | M | Index 2017=100 |
| `cpi_all_urban__CPIAUCSL.csv` | FRED CPIAUCSL | 1947-01– | M | Headline CPI, SA |
| `cpi_core__CPILFESL.csv` | FRED CPILFESL | 1957-01– | M | Core CPI (ex food & energy) |
| `pce_price_index__PCEPI.csv` | FRED PCEPI | 1959-01– | M | Headline PCE deflator |
| `cpi_energy_commodities__CUSR0000SACE.csv` | FRED CUSR0000SACE | 1957-01– | M | Energy sub-index — pass-through measure |
| `fed_funds_rate__FEDFUNDS.csv` | FRED FEDFUNDS | 1954-07– | M | Effective FFR |
| `unemployment_rate__UNRATE.csv` | FRED UNRATE | 1948-01– | M | |
| `oil_wti__DCOILWTICO.csv` | FRED DCOILWTICO | 1986-01– | D | Aggregate to monthly when merging |
| `oil_brent__DCOILBRENTEU.csv` | FRED DCOILBRENTEU | 1987-05– | D | Same |
| `ppi_all_commodities__PPIACO.csv` | FRED PPIACO | 1913-01– | M | Long sample headline |
| `ppi_industrial_commodities__WPSID61.csv` | FRED WPSID61 | 1947-01– | M | Replaces deprecated WPU03THRU15 |
| `umich_expinf_1y__MICH.csv` | FRED MICH | 1978-01– | M | UMich household 1y E[π] |
| `tips_breakeven_5y__T5YIE.csv` | FRED T5YIE | 2003-01– | D | TIPS-implied 5y breakeven |
| `tips_5y5y_forward__T5YIFR.csv` | FRED T5YIFR | 2003-01– | D | 5y5y forward |
| `spread_baa_10y__BAA10Y.csv` | FRED BAA10Y | 1953-04– | D | Moody's BAA minus 10y Treasury |
| `moody_baa_yield__BAA.csv` | FRED BAA | 1919-01– | M | For BAA-AAA spread construction |
| `moody_aaa_yield__AAA.csv` | FRED AAA | 1919-01– | M | |
| `hy_oas__BAMLH0A0HYM2.csv` | FRED BAMLH0A0HYM2 | 1996-12– | D | ICE BofA US HY Master OAS |
| `chicago_fed_nfci__NFCI.csv` | FRED NFCI | 1971-01– | W | Composite financial conditions |
| `gpr_caldara_iacoviello.xls` | matteoiacoviello.com | 1900-01– | M | Sheet contains GPR, GPT, GPA + sub-indices |
| `gscpi_nyfed.xlsx` | NY Fed | 1997-09– | M | Global Supply Chain Pressure Index |
| `ebp_gz_federalreserve.csv` | Fed FEDS Notes | 1973-01– | M | GZ spread + EBP + estimated default prob |
| `spf_inflation.xlsx` | Philadelphia Fed | 1968Q4– | Q | SPF CPI/PCE inflation forecasts |

**Total raw size:** ~4 MB. Small enough to commit; lives in `raw/` for reproducibility.

## Manual downloads needed

These cannot be fetched by curl (paywall, no stable URL, or interactive download):

| Channel | Variable | Source | Why manual |
|---------|----------|--------|-----------|
| Oil | Kilian (2009) supply shock series | https://sites.google.com/site/lkilian2019/research | Author site, ZIP with replication files |
| Commodities | Bloomberg BCOM index | Bloomberg terminal | Subscription |
| Commodities | S&P GSCI Industrial Metals | S&P / Bloomberg | Subscription |
| Commodities | Baltic Dry Index | Bloomberg | Subscription |
| Expectations | NY Fed SCE | https://www.newyorkfed.org/microeconomics/sce | Excel by year, post-2013 only |
| Identification | Caldara–Iacoviello narrative GPR shock | https://www.matteoiacoviello.com/gpr.htm | Separate Excel from main GPR file |

When obtained, save to `raw/` with the same naming convention `<short_label>__<source_code>.<ext>`.

## Sample-period implications

Joining all auto-downloaded series at monthly frequency, the binding constraints on the **common sample** are:

- TIPS breakeven (T5YIE, T5YIFR) → 2003-01
- HY OAS (BAMLH0A0HYM2) → 1996-12
- GSCPI → 1997-09
- EBP/GZ → 1973-01
- MICH → 1978-01
- GPR → unrestricted (1900–)

**Suggested sample windows:**

- **Long sample (1985-01 – present):** drop TIPS, HY OAS, GSCPI; keep MICH, EBP/GZ.
- **Medium sample (1997-10 – present):** keep GSCPI and HY OAS; drop TIPS until 2003.
- **Short sample (2003-01 – present):** all variables available.

The choice will be locked at Stage 2 (design lock) before any LP is estimated.

## Next step

Stage 2 — write `code/01_data_prep.m` to load these files, align dates, build the master monthly panel.
