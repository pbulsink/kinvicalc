# Update calibration factors for an existing viscometer.

Used to correct calibration factors that were entered incorrectly when
the viscometer was first added, without disturbing its use counters,
creation date, or archive status. If `notes` is left blank, an
auto-generated note of the form `"Updated YYYY-MM-DD by <updated_by>"`
is recorded so the correction is traceable.

## Usage

``` r
update_viscometer_factors(
  viscometer_id,
  factor_40_top,
  factor_40_bottom,
  factor_100_top,
  factor_100_bottom,
  notes = NA_character_,
  updated_by = NA_character_
)
```

## Arguments

- viscometer_id:

  A viscometer identifier.

- factor_40_top, factor_40_bottom, factor_100_top, factor_100_bottom:

  Replacement calibration factors.

- notes:

  Optional replacement notes. If `NA` or blank, an auto-generated
  "updated" note is recorded instead.

- updated_by:

  Optional name/identifier of the person making the update, used in the
  auto-generated note.

## Value

The updated viscometer record.

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

update_viscometer_factors(
  "007-00007",
  factor_40_top = 0.0251,
  factor_40_bottom = 0.0251,
  factor_100_top = 0.0251,
  factor_100_bottom = 0.0251,
  updated_by = "jsmith"
)
#> # A tibble: 1 × 16
#>   viscometer_id viscometer_size serial_number status factor_40_top
#>   <chr>                   <int> <chr>         <chr>          <dbl>
#> 1 007-00007                   7 00007         active        0.0251
#> # ℹ 11 more variables: factor_40_bottom <dbl>, factor_100_top <dbl>,
#> #   factor_100_bottom <dbl>, use_count_since_cleaning <int>,
#> #   total_use_count <int>, last_deep_cleaned_at <chr>, archived_at <chr>,
#> #   added_by <chr>, notes <chr>, created_at <chr>, updated_at <chr>

options(old_opt)
```
