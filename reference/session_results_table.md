# Create a session results table.

Create a session results table.

## Usage

``` r
session_results_table(results)
```

## Arguments

- results:

  A list of result objects.

## Value

A tibble summarizing the results.

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

session_results_table(list(result))
#> # A tibble: 1 × 12
#>   operator sample_id viscometer_id sample_type analysis_temperature_c time_1
#>   <chr>    <chr>     <chr>         <chr>                        <dbl>  <dbl>
#> 1 NA       NA        001-00001     unlisted                        40    232
#> # ℹ 6 more variables: time_2 <dbl>, viscosity <dbl>, low_flow_time_flag <lgl>,
#> #   determinability <chr>, locked <lgl>, created_at <dttm>

options(old_opt)
```
