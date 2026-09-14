# kinvicalc - Agent Guidelines

R package implementing ASTM D445-26/D446-24 kinematic viscosity
workflows for viscometer-based testing: record validation, calibration
factor resolution, flow-time calculation (no kinetic energy correction —
see Rounding and flagging conventions below), precision checks
(determinability/repeatability/reproducibility), a “standard”
reference-sample QA/QC check against a known expected value, a local
SQLite reference registry with in-place calibration-factor correction,
and Shiny reporting.

- **Package:** `kinvicalc` v`0.1.0`
- **Authors:** Posit Assistant <assistant@example.com>
- **Repository:** not specified in DESCRIPTION
- **Bug Reports:** not specified in DESCRIPTION

## Package Overview

Provides calculation helpers, validation, persistence, and Shiny
reporting for viscometer-based kinematic viscosity workflows.

All calculation logic is documented against ASTM D445-26 (kinematic
viscosity test method) and ASTM D446-24 (viscometer specifications). If
updating, check with the user for compliance to these standard tests and
specifications.

## Project Structure

No `.github/` CI workflows are currently configured.

### R/ (Source Code)

- `app.R` - Shiny app entry point: two-flow-time measurement form,
  result rendering and locking, viscometer add/update form with
  confirmation modal, standard-sample QA/QC check and colour-coded
  reporting cell. **Must contain only function definitions at top
  level** — see “Running the app” below.
- `calculation-core.R` - ASTM viscosity calculation (`nu = C * t`, no
  kinetic energy/E correction); SQLite reference DB connection, schema
  creation, and default-rule seeding
- `data-models.R` - Required-field validation for viscometer/sample-rule
  records;
  [`build_viscometer_record()`](https://pbulsink.github.io/kinvicalc/reference/build_viscometer_record.md)
  constructor for registry-ready viscometer tibbles; assembles the
  `kinvicalc_result` object from two determinations plus the
  determinability check
- `reporting.R` - Primary and high-density report rendering (HTML/text),
  session results table, result locking state
- `sample-types.R` - Precision rule lookup/upsert and
  determinability/repeatability/reproducibility evaluation (D445-26
  Section 17), including the `"standard"` reference-sample rule set
- `utils.R` - Internal validation asserts, significant-figure
  formatting, default precision-rule seed data; no exports
- `viscometer.R` - Viscometer registry CRUD, calibration factor
  resolution with linear interpolation between 40 C and 100 C, and
  in-place calibration-factor correction via
  [`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md)

### tests/testthat/ (Unit Tests)

testthat edition 3 (`Config/testthat/edition: 3`). Each test file
matches the module it covers in `R/`: - `test-calculation-core.R` -
viscosity above/below minimum flow time (flagged, not corrected),
calibration factor interpolation, round-half-to-even rounding -
`test-data-models.R` - end-to-end result assembly: determinability
pass/fail, low-flow-time flagging, failure warning,
kerosene/diesel/biodiesel rule verification at 40/70/100 C -
`test-sample-types.R` - precision limits for all four formula forms
(linear, offset, power-law, fixed), unverified-cell error, custom rule
upsert/retrieval, `"standard"` rule lookup and determinability across
the full temperature range - `test-viscometer.R` - ID pattern validation
(including alphanumeric serial numbers), registry add/get/remove round
trips,
[`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md)
factor correction and auto-generated/preserved notes - `test-app.R` -
[`evaluate_standard_check()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_standard_check.md)
centering on the expected value (not the measured/expected average),
[`qa_qc_cell()`](https://pbulsink.github.io/kinvicalc/reference/qa_qc_cell.md)
rendering for standard vs. non-standard sample types, and
[`shiny::testServer()`](https://rdrr.io/pkg/shiny/man/testServer.html)
coverage of the standard-sample workflow (missing expected-value
validation, pass/fail r/R display, locked-results table) -
`test-app-source-integrity.R` - Structural (source-scanning) guards for
`R/app.R`: no top-level side-effecting code, every cross-file helper
called namespace-qualified,
[`run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md)
actually exported, and `inst/shiny/app.R` remaining a thin
[`run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md)
delegator that yields a `shiny.appobj`. See “Running the app” below.

## Running the app

Launch the app via the exported
[`kinvicalc::run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md),
or by running the thin launcher
[inst/shiny/app.R](https://pbulsink.github.io/kinvicalc/inst/shiny/app.R)
(the only file that may be used with Positron/RStudio’s “Run App”
button, [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html),
or a Shiny Server / shinyapps.io deploy).

Never `source("R/app.R")`, never use the “Run App” button on `R/app.R`,
and never call `shiny::runApp("R/app.R")`.

Those paths evaluate the file in the **global environment** rather than
the package namespace, where package-internal helpers are invisible.
That produced the recurring runtime error
`could not find function "format_viscometer_id"` (surfaced in the UI as
the “Viscometer rejected” modal). Two defects made it possible, both now
fixed and both regression-tested:

1.  `R/app.R` ended with a top-level `app <- run_app()`, turning the
    file into a runnable single-file Shiny app and inviting the
    source-the-file workflow. Top-level executable code in `R/app.R` is
    now forbidden.
2.  The `@export` roxygen block for
    [`run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md)
    was misplaced above
    [`format_sample_type_label_app()`](https://pbulsink.github.io/kinvicalc/reference/format_sample_type_label_app.md),
    so `run_app` was never exported and users had no supported way to
    start the app.

Rules to preserve: - `R/app.R` contains function definitions only — no
top-level statements. Removing the top-level `app <- run_app()` means
`shiny::runApp("R/app.R")` now correctly fails with “app.R did not
return a shiny.appobj object”; use `inst/shiny/app.R` instead of
re-adding that line. - `inst/shiny/app.R` must stay a thin delegator —
[`library(kinvicalc)`](https://pbulsink.github.io/kinvicalc/) plus
[`kinvicalc::run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md),
nothing more. Copying app logic into it reintroduces the
out-of-namespace bug. - Any helper defined in another `R/*.R` file must
be called from `R/app.R` as `kinvicalc::fn()` (exported) or
`kinvicalc:::fn()` (internal,
e.g. [`calculate_precision_limit()`](https://pbulsink.github.io/kinvicalc/reference/calculate_precision_limit.md)),
never bare. Behavioural `testServer()` tests cannot catch bare calls,
because inside the namespace they always resolve. - Keep each roxygen
block directly above the function it documents; a misplaced block
silently drops the export.

No test file yet exists for `reporting.R`.

### vignettes/ (Documentation)

- `kinvicalc-workflows.Rmd` - End-to-end walkthrough: add a viscometer,
  build a result, render a report. Note that `.Rbuildignore` currently
  excludes `vignettes/`, so built tarballs omit the vignette unless that
  line is removed.

## Architecture Summary

The package is organized as one file per capability area around a single
local SQLite registry (`reference.db`) in the user data directory, which
stores both the viscometer records and the sample-type precision rules:

| File | Role | Key Functions |
|----|----|----|
| `app.R` | Shiny UI and server for interactive measurement, calculation, and result locking; viscometer registry add/update form; standard-sample QA/QC display | [`run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md) |
| `calculation-core.R` | ASTM D445/D446 viscosity calculation (`nu = C * t`, no kinetic energy/E correction) and SQLite reference DB access/initialization | [`calculate_kinematic_viscosity()`](https://pbulsink.github.io/kinvicalc/reference/calculate_kinematic_viscosity.md), [`save_reference_data()`](https://pbulsink.github.io/kinvicalc/reference/save_reference_data.md), [`load_reference_data()`](https://pbulsink.github.io/kinvicalc/reference/load_reference_data.md) |
| `data-models.R` | Record validation and assembly of the result object from two determinations, each resolved against its own bulb’s calibration factor | [`build_sample_result()`](https://pbulsink.github.io/kinvicalc/reference/build_sample_result.md), [`build_viscometer_record()`](https://pbulsink.github.io/kinvicalc/reference/build_viscometer_record.md), [`validate_viscometer_record()`](https://pbulsink.github.io/kinvicalc/reference/validate_viscometer_record.md), [`validate_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/validate_sample_type_rule.md) |
| `reporting.R` | Intermediate report rendering, session results table, and lock state (5 sig. figs default; round to 4 for final client reports per D445-26 15.1) | [`render_primary_report()`](https://pbulsink.github.io/kinvicalc/reference/render_primary_report.md), [`render_high_density_report()`](https://pbulsink.github.io/kinvicalc/reference/render_high_density_report.md), [`lock_result()`](https://pbulsink.github.io/kinvicalc/reference/lock_result.md), [`session_results_table()`](https://pbulsink.github.io/kinvicalc/reference/session_results_table.md) |
| `sample-types.R` | Precision rule management and the three ASTM precision evaluations, limit = a \* (average + offset)^b; includes the `"standard"` reference-sample rule (temperature-unbounded) | [`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md), [`add_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/add_sample_type_rule.md), [`evaluate_determinability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_determinability.md), [`evaluate_repeatability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_repeatability.md), [`evaluate_reproducibility()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_reproducibility.md) |
| `utils.R` | Shared internal infrastructure; no exports (validators used across all modules) | internals: [`.default_sample_rules()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_sample_rules.md), [`.default_reference_db()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_reference_db.md), [`assert_scalar_numeric()`](https://pbulsink.github.io/kinvicalc/reference/assert_scalar_numeric.md), [`format_significant()`](https://pbulsink.github.io/kinvicalc/reference/format_significant.md), [`round_half_even()`](https://pbulsink.github.io/kinvicalc/reference/round_half_even.md) |
| `viscometer.R` | Viscometer registry CRUD, temperature-interpolated calibration factor resolution, and in-place factor correction | [`get_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/get_viscometer.md), [`add_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/add_viscometer.md), [`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md), [`resolve_calibration_factor()`](https://pbulsink.github.io/kinvicalc/reference/resolve_calibration_factor.md), [`list_viscometers()`](https://pbulsink.github.io/kinvicalc/reference/list_viscometers.md), [`validate_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/validate_viscometer.md) |

**Key data flow:**
[`build_sample_result()`](https://pbulsink.github.io/kinvicalc/reference/build_sample_result.md)
is the main orchestrator —
[`get_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/get_viscometer.md)
-\>
[`resolve_calibration_factor()`](https://pbulsink.github.io/kinvicalc/reference/resolve_calibration_factor.md)
(once per bulb: “top” for determination 1, “bottom” for determination 2)
-\>
[`calculate_kinematic_viscosity()`](https://pbulsink.github.io/kinvicalc/reference/calculate_kinematic_viscosity.md)
(twice, one per flow time) -\>
[`evaluate_determinability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_determinability.md)
-\> `kinvicalc_result` object. The DB itself is opened by the internal
[`reference_db_connection()`](https://pbulsink.github.io/kinvicalc/reference/reference_db_connection.md)
(`R/calculation-core.R:120`), which auto-creates both tables at
`tools::R_user_dir("kinvicalc", which = "data")/reference.db` and seeds
[`.default_sample_rules()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_sample_rules.md)
when the `sample_types` table is empty.

**Standard reference-sample QA/QC (`R/app.R`):** selecting sample type
`"standard"` in the Shiny app reveals an “Expected Value” input
(required) and, on calculation, runs
[`evaluate_standard_check()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_standard_check.md)
for both repeatability and reproducibility metrics. Unlike
[`evaluate_repeatability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_repeatability.md)/[`evaluate_reproducibility()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_reproducibility.md)
(which compare two independent measured results and center the limit on
their average),
[`evaluate_standard_check()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_standard_check.md)
compares the single measured result against the known expected value and
centers the limit on the expected value alone
(`limit = coefficient_a * expected_value^exponent_b`, offset applied per
rule). Results are surfaced in the primary report
(repeatability/reproducibility measured-vs-permitted and PASS/FAIL) and,
once locked, in the session results table via
[`qa_qc_cell()`](https://pbulsink.github.io/kinvicalc/reference/qa_qc_cell.md),
which shows colour-coded “Determ / r / R” lines for standard samples and
“Determ” alone for other sample types (replacing the former plain
“Determinability” column).

**Viscometer registry add vs. update (`R/app.R`):** the “Viscometer Data
& Maintenance” form’s action button is a `uiOutput` that renders as “Add
to registry” for a new size/serial combination or “Update Viscometer
Factors” when that combination already exists in the registry (checked
via `new_viscometer_exists()`). Submitting an update pops a confirmation
modal before calling
[`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md),
which corrects only the four calibration factors and `notes` — never
`created_at`, use counters, or archive status. If `notes` is left blank,
an auto-generated `"Updated <date> by <updated_by>"` note is stored
instead so corrections stay traceable.

**Rounding and flagging conventions:** - All reported numeric results
use round-half-to-even (banker’s rounding) via the internal
[`round_half_even()`](https://pbulsink.github.io/kinvicalc/reference/round_half_even.md)
helper in `R/utils.R`, which wraps base R’s native
[`round()`](https://rdrr.io/r/base/Round.html) (already IEC 60559
round-half-to-even). Apply it at the point each reported value is
produced (viscosity, determinability difference/limit). - The package
does **not** implement a kinetic energy (E) correction (D446-24 Eq 6/7).
[`calculate_kinematic_viscosity()`](https://pbulsink.github.io/kinvicalc/reference/calculate_kinematic_viscosity.md)
always uses `nu = C * t` and instead returns `low_flow_time_flag = TRUE`
when `time_s < min_flow_time_s` (200 s default, per ASTM D445-26
6.1.2/10.2). Visual reports
([`render_primary_report()`](https://pbulsink.github.io/kinvicalc/reference/render_primary_report.md),
[`render_high_density_report()`](https://pbulsink.github.io/kinvicalc/reference/render_high_density_report.md),
[`session_results_table()`](https://pbulsink.github.io/kinvicalc/reference/session_results_table.md),
and the Shiny app) surface this flag for operator review rather than
silently correcting it. - Gravity correction is out of scope and must
not be reintroduced; there is no gravitational-acceleration term
anywhere in the calculation path.

**Dependencies:** - **Imports:** bslib, cli, DBI, RSQLite, shiny, tibble
(plus base `tools` for the user data directory) - **Suggested (optional
features):** knitr, rmarkdown (vignettes), testthat \>= 3.0.0 (tests),
withr (declared but not yet used; available for test isolation)

## Standard Workflow

This section describes the typical development and testing workflow for
this package. Agents should follow these steps when making changes:

### 1. Understand the Code Path

- Read roxygen documentation in `R/*.R` to understand function purposes
  and signatures; every calculation cites an ASTM D445-26/D446-24
  section, so preserve those citations when editing formula logic.
- Trace data flow through the modules in the architecture table above.
  Remember that all registry state (viscometers + precision rules) lives
  in one user-level SQLite DB created lazily by
  [`reference_db_connection()`](https://pbulsink.github.io/kinvicalc/reference/reference_db_connection.md).
- Identify which files are affected before proposing changes.

### 2. Make Changes

- Modify only the relevant file(s) in `R/`. Do not create new `.R` files
  unless adding a completely new capability area that does not fit an
  existing module (the package uses one-file-per-capability).
- Follow existing conventions: snake_case names, tibble data throughout,
  and
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)/[`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  for errors and warnings (the package depends on `cli`; do not switch
  back to base
  [`stop()`](https://rdrr.io/r/base/stop.html)/[`sprintf()`](https://rdrr.io/r/base/sprintf.html)
  for new code). Validate scalar inputs with the shared asserts in
  `R/utils.R`
  ([`assert_scalar_numeric()`](https://pbulsink.github.io/kinvicalc/reference/assert_scalar_numeric.md),
  [`assert_string()`](https://pbulsink.github.io/kinvicalc/reference/assert_string.md),
  [`assert_date()`](https://pbulsink.github.io/kinvicalc/reference/assert_date.md)).
- Resolved design debt: the registry still stores separate
  “top”/“bottom” calibration factors, but
  [`build_sample_result()`](https://pbulsink.github.io/kinvicalc/reference/build_sample_result.md)
  now resolves each determination against its own bulb’s factor
  (determination 1 -\> “top”, determination 2 -\> “bottom”) instead of
  using “top” for both. See `R/data-models.R`
  ([`resolve_calibration_factor()`](https://pbulsink.github.io/kinvicalc/reference/resolve_calibration_factor.md)
  called twice) — do not revert to a single shared factor.
- Viscometer serial numbers accept alphanumeric characters
  (`^[A-Za-z0-9]{1,5}$`), zero-padded on the left to 5 characters;
  [`format_viscometer_id()`](https://pbulsink.github.io/kinvicalc/reference/format_viscometer_id.md)/[`is_valid_viscometer_id()`](https://pbulsink.github.io/kinvicalc/reference/is_valid_viscometer_id.md)
  in `R/utils.R` were updated from a digits-only pattern. Preserve
  alphanumeric support in any further ID-handling changes.
- Precision rules with `coefficient_a = NA` are intentional: those
  D445-26 17.2.1/17.2.2 table cells could not be unambiguously
  transcribed, and
  [`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md)
  must keep erroring loudly instead of guessing. Confirm values against
  the standard PDFs before fixing them via
  [`.default_sample_rules()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_sample_rules.md)
  or
  [`add_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/add_sample_type_rule.md).
- The `"standard"` sample type (Characterization Laboratory QA/QC
  reference substance) uses a temperature-unbounded rule (`-Inf`/`Inf`
  bounds) for determinability (0.37%), repeatability (0.56%), and
  reproducibility (1.22%) in
  [`.default_sample_rules()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_sample_rules.md).
  Its repeatability/reproducibility checks
  ([`evaluate_standard_check()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_standard_check.md)
  in `R/app.R`) intentionally center the limit on the expected value
  alone rather than the average of measured and expected — do not
  conflate this with
  [`evaluate_repeatability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_repeatability.md)/[`evaluate_reproducibility()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_reproducibility.md),
  which remain average-centered for two independent measurements.
- When updating viscometer factors via the registry (correcting a
  data-entry error), use
  [`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md)
  rather than
  [`remove_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/remove_viscometer.md) +
  [`add_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/add_viscometer.md),
  so `created_at`, use counters, and archive status are preserved.

### 3. Add Tests

- Create or update tests in `tests/testthat/test-{module}.R`, matching
  the source module name (e.g., changes to `R/viscometer.R` go in
  `test-viscometer.R`). Place new cases adjacent to existing tests for
  the same function, or at the end of the file.
- DB-backed tests share the user-level registry: use a unique viscometer
  ID per test (existing convention is sequential IDs such as
  `"007-00007"`) and clean up with
  [`remove_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/remove_viscometer.md)
  where practical; `withr` is in Suggests if stronger isolation is
  needed.
- Assert error messages by substring and warnings via
  `expect_warning()`/[`suppressWarnings()`](https://rdrr.io/r/base/warning.html)
  (testthat edition 3).
- Run `devtools::test()` to verify all tests pass.
- Ensure new exported functions have usage examples in roxygen
  `@examples` blocks.

### 4. Update Documentation

- Regenerate man pages and NAMESPACE: `devtools::document()` (roxygen2
  with markdown = TRUE).
- Update `vignettes/kinvicalc-workflows.Rmd` if the change affects
  user-facing behavior or examples, remembering it is currently excluded
  from builds by `.Rbuildignore`.

### 5. Verify Build

- Full package check: `devtools::check()`.
- Review test coverage for edited files; aim to cover new validation and
  error paths, matching how existing tests exercise them.
- Ensure no regressions in existing tests and that all file references
  remain valid.

## Testing Philosophy

- Tests assert behavior by recomputing expected values inline from the
  D445-26 formulas (e.g., `0.0037 * y` for base-oil determinability),
  with the standard section cited in a comment — follow this pattern
  when adding precision-related tests.
- Error and warning paths are first-class test targets, matched on
  message substrings (edition 3).
- DB-backed tests intentionally mutate the shared local SQLite registry
  rather than using fixtures or snapshots; keep per-test IDs unique so
  tests remain order-independent.
- Failing tests are valuable — address failures rather than suppressing
  them.

## Test Suite Status (as of 2026-09-14)

`devtools::test()` passes (188/188) and `devtools::check()` completes
with 0 errors, 0 warnings (1 benign NOTE: “unable to verify current
time”). The three previously-failing `test-app.R` cases were test bugs,
not source bugs, and were fixed directly in the test file (no changes
were needed to
[`qa_qc_cell()`](https://pbulsink.github.io/kinvicalc/reference/qa_qc_cell.md)
or the locked-results renderer in `R/app.R`): -
`qa_qc_cell shows only determinability for non-standard sample types`
used `grepl("r:", cell, fixed = TRUE)`, which also matches the substring
`"r:"` inside `"color:"` in the cell’s inline style — tightened to check
for the literal `"r: Pass"`/`"r: Fail"` substrings instead. - The two
`standard` sample-lock tests accessed `output$locked_values_table$html`,
but `locked_values_table` is built with
[`shiny::renderTable()`](https://rdrr.io/pkg/shiny/man/renderTable.html),
which (unlike
[`shiny::renderUI()`](https://rdrr.io/pkg/shiny/man/renderUI.html),
e.g. `output$result`) returns a plain HTML character string under
[`shiny::testServer()`](https://rdrr.io/pkg/shiny/man/testServer.html),
not a `list(html, deps)`. Changed to
`as.character(output$locked_values_table)`.

When adding new `testServer()` assertions against a `renderTable()`
output, use `as.character(output$x)` directly; reserve the `$html`
accessor for `renderUI()`/`renderPrint()`-style outputs.
