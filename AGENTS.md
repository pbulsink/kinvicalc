# kinvicalc - Agent Guidelines

R package implementing ASTM D445-26/D446-24 kinematic viscosity workflows for viscometer-based testing: record validation, calibration factor resolution, flow-time calculation (no kinetic energy correction — see Rounding and flagging conventions below), precision checks (determinability/repeatability/reproducibility), a "standard" reference-sample QA/QC check against a known expected value, a local SQLite reference registry with in-place calibration-factor correction, and Shiny reporting.

- **Package:** `kinvicalc` v`0.1.0`
- **Authors:** Posit Assistant <assistant@example.com>
- **Repository:** not specified in DESCRIPTION
- **Bug Reports:** not specified in DESCRIPTION

## Package Overview

Provides calculation helpers, validation, persistence, and Shiny reporting for viscometer-based kinematic viscosity workflows.

All calculation logic is documented against ASTM D445-26 (kinematic viscosity test method) and ASTM D446-24 (viscometer specifications). If updating, check with the user for compliance to these standard tests and specifications. 

## Project Structure

No `.github/` CI workflows are currently configured.

### R/ (Source Code)
- `app.R` - Shiny app entry point: two-flow-time measurement form, result rendering and locking, viscometer add/update form with confirmation modal, standard-sample QA/QC check and colour-coded reporting cell
- `calculation-core.R` - ASTM viscosity calculation (`nu = C * t`, no kinetic energy/E correction); SQLite reference DB connection, schema creation, and default-rule seeding
- `data-models.R` - Required-field validation for viscometer/sample-rule records; assembles the `kinvicalc_result` object from two determinations plus the determinability check
- `reporting.R` - Primary and high-density report rendering (HTML/text), session results table, result locking state
- `sample-types.R` - Precision rule lookup/upsert and determinability/repeatability/reproducibility evaluation (D445-26 Section 17), including the `"standard"` reference-sample rule set
- `utils.R` - Internal validation asserts, significant-figure formatting, default precision-rule seed data; no exports
- `viscometer.R` - Viscometer registry CRUD, calibration factor resolution with linear interpolation between 40 C and 100 C, and in-place calibration-factor correction via `update_viscometer_factors()`

### tests/testthat/ (Unit Tests)
testthat edition 3 (`Config/testthat/edition: 3`). Each test file matches the module it covers in `R/`:
- `test-calculation-core.R` - viscosity above/below minimum flow time (flagged, not corrected), calibration factor interpolation, round-half-to-even rounding
- `test-data-models.R` - end-to-end result assembly: determinability pass/fail, low-flow-time flagging, failure warning, kerosene/diesel/biodiesel rule verification at 40/70/100 C
- `test-sample-types.R` - precision limits for all four formula forms (linear, offset, power-law, fixed), unverified-cell error, custom rule upsert/retrieval, `"standard"` rule lookup and determinability across the full temperature range
- `test-viscometer.R` - ID pattern validation (including alphanumeric serial numbers), registry add/get/remove round trips, `update_viscometer_factors()` factor correction and auto-generated/preserved notes
- `test-app.R` - `evaluate_standard_check()` centering on the expected value (not the measured/expected average), `qa_qc_cell()` rendering for standard vs. non-standard sample types, and `shiny::testServer()` coverage of the standard-sample workflow (missing expected-value validation, pass/fail r/R display, locked-results table)

No test file yet exists for `reporting.R`.

### vignettes/ (Documentation)
- `kinvicalc-workflows.Rmd` - End-to-end walkthrough: add a viscometer, build a result, render a report. Note that `.Rbuildignore` currently excludes `vignettes/`, so built tarballs omit the vignette unless that line is removed.

## Architecture Summary

The package is organized as one file per capability area around a single local SQLite registry (`reference.db`) in the user data directory, which stores both the viscometer records and the sample-type precision rules:

| File | Role | Key Functions |
|------|------|---------------|
| `app.R` | Shiny UI and server for interactive measurement, calculation, and result locking; viscometer registry add/update form; standard-sample QA/QC display | `run_app()` |
| `calculation-core.R` | ASTM D445/D446 viscosity calculation (`nu = C * t`, no kinetic energy/E correction) and SQLite reference DB access/initialization | `calculate_kinematic_viscosity()`, `save_reference_data()`, `load_reference_data()` |
| `data-models.R` | Record validation and assembly of the result object from two determinations, each resolved against its own bulb's calibration factor | `build_sample_result()`, `validate_viscometer_record()`, `validate_sample_type_rule()` |
| `reporting.R` | Intermediate report rendering, session results table, and lock state (5 sig. figs default; round to 4 for final client reports per D445-26 15.1) | `render_primary_report()`, `render_high_density_report()`, `lock_result()`, `session_results_table()` |
| `sample-types.R` | Precision rule management and the three ASTM precision evaluations, limit = a * (average + offset)^b; includes the `"standard"` reference-sample rule (temperature-unbounded) | `get_sample_type_rule()`, `add_sample_type_rule()`, `evaluate_determinability()`, `evaluate_repeatability()`, `evaluate_reproducibility()` |
| `utils.R` | Shared internal infrastructure; no exports (validators used across all modules) | internals: `.default_sample_rules()`, `.default_reference_db()`, `assert_scalar_numeric()`, `format_significant()`, `round_half_even()` |
| `viscometer.R` | Viscometer registry CRUD, temperature-interpolated calibration factor resolution, and in-place factor correction | `get_viscometer()`, `add_viscometer()`, `update_viscometer_factors()`, `resolve_calibration_factor()`, `list_viscometers()`, `validate_viscometer()` |

**Key data flow:** `build_sample_result()` is the main orchestrator — `get_viscometer()` -> `resolve_calibration_factor()` (once per bulb: "top" for determination 1, "bottom" for determination 2) -> `calculate_kinematic_viscosity()` (twice, one per flow time) -> `evaluate_determinability()` -> `kinvicalc_result` object. The DB itself is opened by the internal `reference_db_connection()` (`R/calculation-core.R:120`), which auto-creates both tables at `tools::R_user_dir("kinvicalc", which = "data")/reference.db` and seeds `.default_sample_rules()` when the `sample_types` table is empty.

**Standard reference-sample QA/QC (`R/app.R`):** selecting sample type `"standard"` in the Shiny app reveals an "Expected Value" input (required) and, on calculation, runs `evaluate_standard_check()` for both repeatability and reproducibility metrics. Unlike `evaluate_repeatability()`/`evaluate_reproducibility()` (which compare two independent measured results and center the limit on their average), `evaluate_standard_check()` compares the single measured result against the known expected value and centers the limit on the expected value alone (`limit = coefficient_a * expected_value^exponent_b`, offset applied per rule). Results are surfaced in the primary report (repeatability/reproducibility measured-vs-permitted and PASS/FAIL) and, once locked, in the session results table via `qa_qc_cell()`, which shows colour-coded "Determ / r / R" lines for standard samples and "Determ" alone for other sample types (replacing the former plain "Determinability" column).

**Viscometer registry add vs. update (`R/app.R`):** the "Viscometer Data & Maintenance" form's action button is a `uiOutput` that renders as "Add to registry" for a new size/serial combination or "Update Viscometer Factors" when that combination already exists in the registry (checked via `new_viscometer_exists()`). Submitting an update pops a confirmation modal before calling `update_viscometer_factors()`, which corrects only the four calibration factors and `notes` — never `created_at`, use counters, or archive status. If `notes` is left blank, an auto-generated `"Updated <date> by <updated_by>"` note is stored instead so corrections stay traceable.

**Rounding and flagging conventions:**
- All reported numeric results use round-half-to-even (banker's rounding) via the internal `round_half_even()` helper in `R/utils.R`, which wraps base R's native `round()` (already IEC 60559 round-half-to-even). Apply it at the point each reported value is produced (viscosity, determinability difference/limit).
- The package does **not** implement a kinetic energy (E) correction (D446-24 Eq 6/7). `calculate_kinematic_viscosity()` always uses `nu = C * t` and instead returns `low_flow_time_flag = TRUE` when `time_s < min_flow_time_s` (200 s default, per ASTM D445-26 6.1.2/10.2). Visual reports (`render_primary_report()`, `render_high_density_report()`, `session_results_table()`, and the Shiny app) surface this flag for operator review rather than silently correcting it.
- Gravity correction is out of scope and must not be reintroduced; there is no gravitational-acceleration term anywhere in the calculation path.

**Dependencies:**
- **Imports:** bslib, cli, DBI, RSQLite, shiny, tibble (plus base `tools` for the user data directory)
- **Suggested (optional features):** knitr, rmarkdown (vignettes), testthat >= 3.0.0 (tests), withr (declared but not yet used; available for test isolation)

## Standard Workflow

This section describes the typical development and testing workflow for this package. Agents should follow these steps when making changes:

### 1. Understand the Code Path
- Read roxygen documentation in `R/*.R` to understand function purposes and signatures; every calculation cites an ASTM D445-26/D446-24 section, so preserve those citations when editing formula logic.
- Trace data flow through the modules in the architecture table above. Remember that all registry state (viscometers + precision rules) lives in one user-level SQLite DB created lazily by `reference_db_connection()`.
- Identify which files are affected before proposing changes.

### 2. Make Changes
- Modify only the relevant file(s) in `R/`. Do not create new `.R` files unless adding a completely new capability area that does not fit an existing module (the package uses one-file-per-capability).
- Follow existing conventions: snake_case names, tibble data throughout, and `cli::cli_abort()`/`cli::cli_warn()` for errors and warnings (the package depends on `cli`; do not switch back to base `stop()`/`sprintf()` for new code). Validate scalar inputs with the shared asserts in `R/utils.R` (`assert_scalar_numeric()`, `assert_string()`, `assert_date()`).
- Resolved design debt: the registry still stores separate "top"/"bottom" calibration factors, but `build_sample_result()` now resolves each determination against its own bulb's factor (determination 1 -> "top", determination 2 -> "bottom") instead of using "top" for both. See `R/data-models.R` (`resolve_calibration_factor()` called twice) — do not revert to a single shared factor.
- Viscometer serial numbers accept alphanumeric characters (`^[A-Za-z0-9]{1,5}$`), zero-padded on the left to 5 characters; `format_viscometer_id()`/`is_valid_viscometer_id()` in `R/utils.R` were updated from a digits-only pattern. Preserve alphanumeric support in any further ID-handling changes.
- Precision rules with `coefficient_a = NA` are intentional: those D445-26 17.2.1/17.2.2 table cells could not be unambiguously transcribed, and `get_sample_type_rule()` must keep erroring loudly instead of guessing. Confirm values against the standard PDFs before fixing them via `.default_sample_rules()` or `add_sample_type_rule()`.
- The `"standard"` sample type (Characterization Laboratory QA/QC reference substance) uses a temperature-unbounded rule (`-Inf`/`Inf` bounds) for determinability (0.37%), repeatability (0.56%), and reproducibility (1.22%) in `.default_sample_rules()`. Its repeatability/reproducibility checks (`evaluate_standard_check()` in `R/app.R`) intentionally center the limit on the expected value alone rather than the average of measured and expected — do not conflate this with `evaluate_repeatability()`/`evaluate_reproducibility()`, which remain average-centered for two independent measurements.
- When updating viscometer factors via the registry (correcting a data-entry error), use `update_viscometer_factors()` rather than `remove_viscometer()` + `add_viscometer()`, so `created_at`, use counters, and archive status are preserved.

### 3. Add Tests
- Create or update tests in `tests/testthat/test-{module}.R`, matching the source module name (e.g., changes to `R/viscometer.R` go in `test-viscometer.R`). Place new cases adjacent to existing tests for the same function, or at the end of the file.
- DB-backed tests share the user-level registry: use a unique viscometer ID per test (existing convention is sequential IDs such as `"007-00007"`) and clean up with `remove_viscometer()` where practical; `withr` is in Suggests if stronger isolation is needed.
- Assert error messages by substring and warnings via `expect_warning()`/`suppressWarnings()` (testthat edition 3).
- Run `devtools::test()` to verify all tests pass.
- Ensure new exported functions have usage examples in roxygen `@examples` blocks.

### 4. Update Documentation
- Regenerate man pages and NAMESPACE: `devtools::document()` (roxygen2 with markdown = TRUE).
- Update `vignettes/kinvicalc-workflows.Rmd` if the change affects user-facing behavior or examples, remembering it is currently excluded from builds by `.Rbuildignore`.

### 5. Verify Build
- Full package check: `devtools::check()`.
- Review test coverage for edited files; aim to cover new validation and error paths, matching how existing tests exercise them.
- Ensure no regressions in existing tests and that all file references remain valid.

## Testing Philosophy

- Tests assert behavior by recomputing expected values inline from the D445-26 formulas (e.g., `0.0037 * y` for base-oil determinability), with the standard section cited in a comment — follow this pattern when adding precision-related tests.
- Error and warning paths are first-class test targets, matched on message substrings (edition 3).
- DB-backed tests intentionally mutate the shared local SQLite registry rather than using fixtures or snapshots; keep per-test IDs unique so tests remain order-independent.
- Failing tests are valuable — address failures rather than suppressing them.

## Test Suite Status (as of 2026-09-14)

`devtools::test()` passes (188/188) and `devtools::check()` completes with 0 errors, 0 warnings (1 benign NOTE: "unable to verify current time"). The three previously-failing `test-app.R` cases were test bugs, not source bugs, and were fixed directly in the test file (no changes were needed to `qa_qc_cell()` or the locked-results renderer in `R/app.R`):
- `qa_qc_cell shows only determinability for non-standard sample types` used `grepl("r:", cell, fixed = TRUE)`, which also matches the substring `"r:"` inside `"color:"` in the cell's inline style — tightened to check for the literal `"r: Pass"`/`"r: Fail"` substrings instead.
- The two `standard` sample-lock tests accessed `output$locked_values_table$html`, but `locked_values_table` is built with `shiny::renderTable()`, which (unlike `shiny::renderUI()`, e.g. `output$result`) returns a plain HTML character string under `shiny::testServer()`, not a `list(html, deps)`. Changed to `as.character(output$locked_values_table)`.

When adding new `testServer()` assertions against a `renderTable()` output, use `as.character(output$x)` directly; reserve the `$html` accessor for `renderUI()`/`renderPrint()`-style outputs.

