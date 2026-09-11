# kinvicalc

`kinvicalc` is an R package for kinematic viscosity calculations and reporting in ASTM-style laboratory workflows. It provides a reusable API for:

- validating viscometer records
- resolving calibration factors
- calculating kinematic viscosity
- evaluating determinability rules
- storing viscometer and sample-type metadata locally
- generating print-friendly sample and session reports

  <!-- badges: start -->
  [![R-CMD-check](https://github.com/pbulsink/kinvicalc/actions/workflows/R-CMD-check.yaml/badge.svghttps://github.com/pbulsink/kinvicalc/actions/workflows/R-CMD-check.yaml/badge.svghttps://github.com/pbulsink/kinvicalc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pbulsink/kinvicalc/actions/workflows/R-CMD-check.yaml)
  [![Coverage Status](https://coveralls.io/repos/github/pbulsink/kinvicalc/badge.svg?branch=main)](https://coveralls.io/github/pbulsink/kinvicalc?branch=main)
  <!-- badges: end -->

## Example

```r
library(kinvicalc)

viscometer <- tibble::tibble(
  viscometer_id = "001-00001",
  viscometer_size = 1,
  serial_number = "00001",
  calibration_date = as.Date("2024-01-01"),
  status = "active",
  factor_40_top = 0.025,
  factor_40_bottom = 0.029,
  factor_100_top = 0.016,
  factor_100_bottom = 0.018
)

add_viscometer(viscometer)

result <- build_sample_result(
  viscometer_id = "001-00001",
  sample_type = "oil",
  analysis_temperature_c = 40,
  time_top = 200,
  time_bottom = 210
)

result$kinematic_viscosity_cSt
```

## App

```r
library(kinvicalc)
run_app()
```
