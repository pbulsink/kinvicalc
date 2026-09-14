# Build a sample result record.

Assembles the two determined kinematic viscosity values (from the two
flow-time measurements on the same viscometer, ASTM D445-26 11.2/14.1),
checks determinability, and – if the two values agree – averages them
into a single reported result. This package does not apply a kinetic
energy correction; instead, any flow time below `min_flow_time_s` is
flagged (`low_flow_time_flag`) so it can be surfaced in reports for
operator review (ASTM D445-26 6.1.2/10.2).

## Usage

``` r
build_sample_result(
  viscometer_id,
  sample_type,
  analysis_temperature_c,
  time_1,
  time_2,
  min_flow_time_s = MIN_FLOW_TIME_S,
  operator = NA_character_,
  sample_id = NA_character_,
  notes = NA_character_
)
```

## Arguments

- viscometer_id:

  Viscometer identifier.

- sample_type:

  Sample type label (see
  [`.default_sample_rules()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_sample_rules.md)).

- analysis_temperature_c:

  Analysis temperature in C.

- time_1:

  First measured flow time, s.

- time_2:

  Second measured flow time, s.

- min_flow_time_s:

  Minimum flow time, s, below which a result is flagged. Defaults to 200
  s (ASTM D445-26 6.1.2/10.2); override with the
  viscometer/size-specific minimum from Specifications D446 when it is
  higher.

- operator:

  Optional operator/user identifier performing the determination.
  Recorded on the result for traceability.

- sample_id:

  Optional sample identifier/name being tested. Recorded on the result
  for traceability.

- notes:

  Optional notes.

## Value

A list-like result object. If the determinability check fails, the
result is still returned (with `determinability_result == "fail"`) so
the caller/UI can prompt for a repeat measurement per ASTM D445-26
11.2.3/12.4.1 – `kinvicalc` does not silently average a failing pair.

## Examples

``` r
# Use a temporary registry so the example does not touch the real
# user-level reference.db.
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

add_viscometer(
  build_viscometer_record(
    viscometer_size = 1,
    serial_number = "00001",
    factor_40_top = 0.025,
    factor_40_bottom = 0.029,
    factor_100_top = 0.016,
    factor_100_bottom = 0.018
  )
)
#> # A tibble: 1 × 16
#>   viscometer_id viscometer_size serial_number status factor_40_top
#>   <chr>                   <int> <chr>         <chr>          <dbl>
#> 1 001-00001                   1 00001         active         0.025
#> # ℹ 11 more variables: factor_40_bottom <dbl>, factor_100_top <dbl>,
#> #   factor_100_bottom <dbl>, use_count_since_cleaning <int>,
#> #   total_use_count <int>, last_deep_cleaned_at <chr>, archived_at <chr>,
#> #   added_by <chr>, notes <chr>, created_at <chr>, updated_at <chr>

result <- build_sample_result(
  viscometer_id = "001-00001",
  sample_type = "unlisted",
  analysis_temperature_c = 40,
  time_1 = 232,
  time_2 = 200
)
result$kinematic_viscosity_cSt
#> [1] 5.8

options(old_opt)
```
