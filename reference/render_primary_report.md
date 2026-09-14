# Render a primary sample report.

Render a primary sample report.

## Usage

``` r
render_primary_report(result, output_path = NULL, digits = 5)
```

## Arguments

- result:

  A result object created by
  [`build_sample_result()`](https://pbulsink.github.io/kinvicalc/reference/build_sample_result.md).

- output_path:

  Optional output file path for PDF or HTML export.

- digits:

  Minimum significant figures to report (default 5, for intermediate
  reports; use 4 for a final client report per ASTM D445-26 15.1).

## Value

Invisibly the result object.

## Examples

``` r
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

# Print to console (no output_path -> no file written)
render_primary_report(result)

# Write an HTML report to a file
report_path <- tempfile(fileext = ".html")
render_primary_report(result, output_path = report_path)

options(old_opt)
```
