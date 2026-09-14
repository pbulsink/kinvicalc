# Package index

## Calculating kinematic viscosity

Core ASTM D445-26 Eq 2 / D446-24 Eq 5 calculation (`nu = C * t`), and
the full two-determination workflow that resolves calibration factors,
calculates both determinations, and checks determinability in one call.

- [`calculate_kinematic_viscosity()`](https://pbulsink.github.io/kinvicalc/reference/calculate_kinematic_viscosity.md)
  : Calculate kinematic viscosity from time and calibration constant.
- [`build_sample_result()`](https://pbulsink.github.io/kinvicalc/reference/build_sample_result.md)
  : Build a sample result record.

## Viscometer registry

Add, look up, and maintain viscometers in the local SQLite registry,
including archiving, use-count tracking, and in-place calibration-factor
correction.

- [`build_viscometer_record()`](https://pbulsink.github.io/kinvicalc/reference/build_viscometer_record.md)
  : Build a viscometer record tibble.
- [`validate_viscometer_record()`](https://pbulsink.github.io/kinvicalc/reference/validate_viscometer_record.md)
  : Validate a viscometer record.
- [`validate_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/validate_viscometer.md)
  : Validate a viscometer identifier.
- [`format_viscometer_id()`](https://pbulsink.github.io/kinvicalc/reference/format_viscometer_id.md)
  : Format a viscometer ID
- [`add_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/add_viscometer.md)
  : Add a viscometer record to the local registry.
- [`get_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/get_viscometer.md)
  : Get one viscometer by identifier.
- [`list_viscometers()`](https://pbulsink.github.io/kinvicalc/reference/list_viscometers.md)
  : List all viscometers in the local registry.
- [`list_active_viscometers()`](https://pbulsink.github.io/kinvicalc/reference/list_active_viscometers.md)
  : List active viscometers in the local registry.
- [`list_archived_viscometers()`](https://pbulsink.github.io/kinvicalc/reference/list_archived_viscometers.md)
  : List archived viscometers in the local registry.
- [`archive_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/archive_viscometer.md)
  : Archive a viscometer in the local registry.
- [`unarchive_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/unarchive_viscometer.md)
  : Unarchive a viscometer in the local registry.
- [`remove_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/remove_viscometer.md)
  : Remove a viscometer from the local registry.
- [`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md)
  : Update calibration factors for an existing viscometer.
- [`resolve_calibration_factor()`](https://pbulsink.github.io/kinvicalc/reference/resolve_calibration_factor.md)
  : Resolve the calibration factor for a specific bulb and temperature.
- [`increment_viscometer_use()`](https://pbulsink.github.io/kinvicalc/reference/increment_viscometer_use.md)
  : Increment viscometer use counters by one.
- [`reset_viscometer_use_count()`](https://pbulsink.github.io/kinvicalc/reference/reset_viscometer_use_count.md)
  : Reset viscometer use count since deep cleaning.
- [`get_viscometer_use_summary()`](https://pbulsink.github.io/kinvicalc/reference/get_viscometer_use_summary.md)
  : Get viscometer use counters.

## Precision checks (determinability, repeatability, reproducibility)

ASTM D445-26 Section 17 precision rules and the checks that compare
measured values against them.

- [`validate_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/validate_sample_type_rule.md)
  : Validate a sample-type precision rule.
- [`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md)
  : Get a sample-type precision rule.
- [`add_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/add_sample_type_rule.md)
  : Add or replace a sample type precision rule.
- [`evaluate_determinability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_determinability.md)
  : Evaluate determinability for a sample at a given temperature.
- [`evaluate_repeatability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_repeatability.md)
  : Evaluate repeatability between two independent results.
- [`evaluate_reproducibility()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_reproducibility.md)
  : Evaluate reproducibility between two independent results from
  different labs.

## Reporting and session state

Render sample and session reports, lock results once reviewed, and
format numeric/label output for display.

- [`render_primary_report()`](https://pbulsink.github.io/kinvicalc/reference/render_primary_report.md)
  : Render a primary sample report.
- [`render_high_density_report()`](https://pbulsink.github.io/kinvicalc/reference/render_high_density_report.md)
  : Render a high-density locked sample report.
- [`lock_result()`](https://pbulsink.github.io/kinvicalc/reference/lock_result.md)
  : Lock a result in the session state.
- [`session_results_table()`](https://pbulsink.github.io/kinvicalc/reference/session_results_table.md)
  : Create a session results table.
- [`format_significant()`](https://pbulsink.github.io/kinvicalc/reference/format_significant.md)
  : Format a numeric value to at least a given number of significant
  figures.

## Reference data storage

Save and load the local SQLite registry (viscometers and sample-type
precision rules) as a whole.

- [`save_reference_data()`](https://pbulsink.github.io/kinvicalc/reference/save_reference_data.md)
  : Save reference data to the local database.
- [`load_reference_data()`](https://pbulsink.github.io/kinvicalc/reference/load_reference_data.md)
  : Load reference data from the local database.

## Shiny application

Launch the interactive measurement and registry-maintenance app.

- [`run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md)
  : Run the kinvicalc Shiny application.
- [`format_sample_type_label_app()`](https://pbulsink.github.io/kinvicalc/reference/format_sample_type_label_app.md)
  : Format a sample type code as a human-readable label.
