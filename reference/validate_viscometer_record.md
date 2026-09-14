# Validate a viscometer record.

Checks that a viscometer record contains all required columns and valid
values.

## Usage

``` r
validate_viscometer_record(viscometer)
```

## Arguments

- viscometer:

  A data frame-like object representing one viscometer.

## Value

The validated viscometer tibble.

## Examples

``` r
validate_viscometer_record(
  tibble::tibble(
    viscometer_size = 75,
    serial_number = "294",
    status = "active",
    factor_40_top = 0.00842,
    factor_40_bottom = 0.00609,
    factor_100_top = 0.00847,
    factor_100_bottom = 0.00614
  )
)
#> # A tibble: 1 × 8
#>   viscometer_size serial_number status factor_40_top factor_40_bottom
#>             <dbl> <chr>         <chr>          <dbl>            <dbl>
#> 1              75 294           active       0.00842          0.00609
#> # ℹ 3 more variables: factor_100_top <dbl>, factor_100_bottom <dbl>,
#> #   viscometer_id <chr>
```
