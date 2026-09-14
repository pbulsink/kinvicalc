# Calculate kinematic viscosity from time and calibration constant.

Implements the basic relationship of ASTM D445-26 Eq 2 / D446-24 Eq 5,
`nu = C * t`. No kinetic energy correction is applied by this package;
instead, when `time_s` is below `min_flow_time_s`, the result is flagged
(`low_flow_time_flag`) so it can be surfaced in reports for operator
review, per ASTM D445-26 6.1.2/10.2.

## Usage

``` r
calculate_kinematic_viscosity(
  time_s,
  factor,
  min_flow_time_s = MIN_FLOW_TIME_S
)
```

## Arguments

- time_s:

  Time in seconds.

- factor:

  Calibration constant (`C`) for the relevant viscometer, in mm2/s2.

- min_flow_time_s:

  Minimum flow time, in seconds, below which the result is flagged.
  Defaults to the general 200 s minimum from ASTM D445-26 6.1.2/10.2;
  pass the viscometer- or size-specific minimum from Specifications D446
  when it differs (some sizes require 250 s, 300 s, 380 s, 600 s, or
  1320 s – see D446-24 Annexes A1-A3).

## Value

A list with the calculated kinematic viscosity (`viscosity`, in mm2/s)
and whether the flow time is below the minimum (`low_flow_time_flag`).

## Examples

``` r
calculate_kinematic_viscosity(time_s = 232, factor = 0.025)
#> $viscosity
#> [1] 5.8
#> 
#> $low_flow_time_flag
#> [1] FALSE
#> 
calculate_kinematic_viscosity(time_s = 150, factor = 0.025)
#> $viscosity
#> [1] 3.75
#> 
#> $low_flow_time_flag
#> [1] TRUE
#> 
```
