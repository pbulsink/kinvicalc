# Get viscometer use counters.

Returns the current use summary for a single viscometer, including the
number of uses since the last deep cleaning and the overall lifetime use
count.

## Usage

``` r
get_viscometer_use_summary(viscometer_id)
```

## Arguments

- viscometer_id:

  A viscometer identifier.

## Value

A one-row tibble with `viscometer_id`, `use_count_since_cleaning`,
`total_use_count`, and `last_deep_cleaned_at`.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

add_viscometer(
  build_viscometer_record(
    viscometer_size = 7,
    serial_number = "00007",
    factor_40_top = 0.025,
    factor_40_bottom = 0.029,
    factor_100_top = 0.016,
    factor_100_bottom = 0.018
  )
)
#> # A tibble: 1 × 16
#>   viscometer_id viscometer_size serial_number status factor_40_top
#>   <chr>                   <int> <chr>         <chr>          <dbl>
#> 1 007-00007                   7 00007         active         0.025
#> # ℹ 11 more variables: factor_40_bottom <dbl>, factor_100_top <dbl>,
#> #   factor_100_bottom <dbl>, use_count_since_cleaning <int>,
#> #   total_use_count <int>, last_deep_cleaned_at <chr>, archived_at <chr>,
#> #   added_by <chr>, notes <chr>, created_at <chr>, updated_at <chr>
get_viscometer_use_summary("007-00007")
#> # A tibble: 1 × 4
#>   viscometer_id use_count_since_cleaning total_use_count last_deep_cleaned_at
#>   <chr>                            <int>           <int> <chr>               
#> 1 007-00007                            0               0 NA                  

options(old_opt)
```
