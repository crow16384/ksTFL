# ksTFL Examples

This folder contains the **curated, package-ready** runnable examples.

## Folder structure

- `full_cycle_render.R` — comprehensive end-to-end script (broad feature coverage)
- `init.R` — legacy-compatible global setup used by `full_cycle_render.R`
- `index.R` — entrypoint runner (delegates to curated showcase)
- `showcase/` — modular examples, including premium submission workflows

## Naming convention

- Full-cycle outputs: `full_cycle_XX_*`
- Showcase outputs: `showcase_XX_*`
- Premium outputs: `premium_XX_*`
- Transfer/index package: `premium_08_*`

This keeps output names deterministic and easy to inventory.

## Curated showcase scripts

| Script | Description |
|--------|-------------|
| `showcase/01_clinical_table_showcase.R` | Clinical table with hidden helper cols, row actions (`c_addrow`, `c_merge`, `c_glue`, `c_pageBreak`) |
| `showcase/02_listing_paging_colbreak.R` | Large listing with grouping/paging and horizontal column break |
| `showcase/03_narrative_figure_table.R` | Mixed report: narrative text + figure + summary table |
| `showcase/04_meta_replay_clean.R` | Metadata workflow (`save_report`, `list_reports`, `replay_report`, `clean_reports`) |
| `showcase/05_premium_csr_bundle.R` | Premium CSR-style multi-section bundle |
| `showcase/06_premium_qc_repro.R` | Premium QC reproducibility pipeline (dual-run, replay, cleanup preview) |
| `showcase/07_premium_submission_multilang_templates.R` | Premium EN/RU submission variants with switchable templates |
| `showcase/08_premium_submission_index_bundle.R` | Builds transfer bundle (`docs`, manifest, checksums) and DOCX index |
| `showcase/09_template_override_multi_spec.R` | Multi-spec template behavior: per-spec docTemplate vs global template_json override |
| `showcase/10_ae_template_ru.R` | Russian template-style AE table (SOC/PT + severity with multi-level period headers) |
| `showcase/11_ae_template_ru_real_counts.R` | Russian AE template variant with computed n (%) and E from synthetic event data |
| `showcase/run_all_showcase.R` | Runs all curated scripts end-to-end |

## How to run

```r
devtools::load_all()
source("inst/examples/index.R")
```

Primary output directory: `tmp/showcase_output/`.
