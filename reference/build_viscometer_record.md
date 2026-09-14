# Build a viscometer record tibble.

Assembles a one-row viscometer record with the columns required by
[`add_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/add_viscometer.md)
and
[`validate_viscometer_record()`](https://pbulsink.github.io/kinvicalc/reference/validate_viscometer_record.md),
deriving `viscometer_id` from `viscometer_size` and `serial_number`. The
assembled record is validated before it is returned, so an invalid size,
serial number, or calibration factor fails here rather than at insert
time.

## Usage

``` r
build_viscometer_record(
  viscometer_size,
  serial_number,
  factor_40_top,
  factor_40_bottom,
  factor_100_top,
  factor_100_bottom,
  status = "active",
  added_by = NULL,
  notes = NULL
)
```

## Arguments

- viscometer_size:

  Integer viscometer size between 1 and 999, used as the three-digit ID
  prefix.

- serial_number:

  Alphanumeric serial number, at most 5 characters, zero-padded on the
  left in the assembled ID.

- factor_40_top, factor_40_bottom:

  Calibration factors at 40 C for the top and bottom bulbs, mm2/s per
  second.

- factor_100_top, factor_100_bottom:

  Calibration factors at 100 C for the top and bottom bulbs, mm2/s per
  second.

- status:

  Registry status string; defaults to `"active"`.

- added_by:

  Optional name of the person adding the record.

- notes:

  Optional free-text notes.

## Value

A validated one-row viscometer tibble including `viscometer_id`.

## Details

All four calibration factors are required: ASTM D446-24 specifies a
separate constant per bulb, and
[`resolve_calibration_factor()`](https://pbulsink.github.io/kinvicalc/reference/resolve_calibration_factor.md)
interpolates between the 40 C and 100 C values, so no factor has a
meaningful default.

## Examples

``` r
build_viscometer_record(
  viscometer_size = 75,
  serial_number = "294",
  factor_40_top = 0.00842,
  factor_40_bottom = 0.00609,
  factor_100_top = 0.00847,
  factor_100_bottom = 0.00614
)
#> # A tibble: 1 × 10
#>   viscometer_size serial_number status factor_40_top factor_40_bottom
#>             <dbl> <chr>         <chr>          <dbl>            <dbl>
#> 1              75 294           active       0.00842          0.00609
#> # ℹ 5 more variables: factor_100_top <dbl>, factor_100_bottom <dbl>,
#> #   added_by <chr>, notes <chr>, viscometer_id <chr>
```
