# Resolve the calibration factor for a specific bulb and temperature.

Resolve the calibration factor for a specific bulb and temperature.

## Usage

``` r
resolve_calibration_factor(
  viscometer,
  temperature_c,
  bulb = c("top", "bottom")
)
```

## Arguments

- viscometer:

  A validated viscometer record.

- temperature_c:

  Temperature in Celsius.

- bulb:

  Which bulb to resolve: top or bottom.

## Value

Calibration factor for the requested bulb and temperature.

## Examples

``` r
viscometer <- build_viscometer_record(
  viscometer_size = 1,
  serial_number = "00001",
  factor_40_top = 0.025,
  factor_40_bottom = 0.029,
  factor_100_top = 0.016,
  factor_100_bottom = 0.018
)

# At a tabulated temperature
resolve_calibration_factor(viscometer, 40, bulb = "top")
#> [1] 0.025

# Interpolated between 40 C and 100 C
resolve_calibration_factor(viscometer, 70, bulb = "top")
#> [1] 0.0205
```
