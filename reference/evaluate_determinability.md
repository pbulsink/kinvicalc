# Evaluate determinability for a sample at a given temperature.

Per ASTM D445-26 11.2.3/14.1, determinability compares the two
*determined* kinematic viscosity values (not the raw flow times) that
are averaged to produce one reported result.

## Usage

``` r
evaluate_determinability(
  sample_type,
  analysis_temperature_c,
  viscosity_1,
  viscosity_2
)
```

## Arguments

- sample_type:

  Sample type label.

- analysis_temperature_c:

  Analysis temperature in C.

- viscosity_1:

  First determined kinematic viscosity value, mm2/s.

- viscosity_2:

  Second determined kinematic viscosity value, mm2/s.

## Value

A list containing the difference, rule limit, and pass/fail status.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

evaluate_determinability(
  sample_type = "base_oil",
  analysis_temperature_c = 40,
  viscosity_1 = 5.80,
  viscosity_2 = 5.79
)
#> $sample_type
#> [1] "base_oil"
#> 
#> $analysis_temperature_c
#> [1] 40
#> 
#> $average_viscosity
#> [1] 5.795
#> 
#> $difference
#> [1] 0.01
#> 
#> $limit
#> [1] 0.0214415
#> 
#> $result
#> [1] "pass"
#> 
#> $passed
#> [1] TRUE
#> 

options(old_opt)
```
