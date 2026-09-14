# List all viscometers in the local registry.

Includes use counters (`use_count_since_cleaning`, `total_use_count`)
and the most recent deep-clean timestamp (`last_deep_cleaned_at`) when
available.

## Usage

``` r
list_viscometers()
```

## Value

A tibble of viscometer records.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

list_viscometers()
#> # A tibble: 0 × 16
#> # ℹ 16 variables: viscometer_id <chr>, viscometer_size <dbl>,
#> #   serial_number <chr>, status <chr>, factor_40_top <dbl>,
#> #   factor_40_bottom <dbl>, factor_100_top <dbl>, factor_100_bottom <dbl>,
#> #   use_count_since_cleaning <int>, total_use_count <int>,
#> #   last_deep_cleaned_at <chr>, archived_at <chr>, added_by <chr>, notes <chr>,
#> #   created_at <chr>, updated_at <chr>

options(old_opt)
```
