# Evaluate repeatability between two independent results.

Per ASTM D445-26 17.2.1, repeatability compares two independent
*results* (each already the average of two determined values) obtained
by the same operator/lab/apparatus on identical material within a short
time interval.

## Usage

``` r
evaluate_repeatability(sample_type, analysis_temperature_c, result_1, result_2)
```

## Arguments

- sample_type:

  Sample type label.

- analysis_temperature_c:

  Analysis temperature in C.

- result_1:

  First reported kinematic viscosity result, mm2/s.

- result_2:

  Second reported kinematic viscosity result, mm2/s.

## Value

A list containing the difference, rule limit, and pass/fail status.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

evaluate_repeatability(
  sample_type = "base_oil",
  analysis_temperature_c = 40,
  result_1 = 5.80,
  result_2 = 5.75
)
#> $sample_type
#> [1] "base_oil"
#> 
#> $analysis_temperature_c
#> [1] 40
#> 
#> $average_result
#> [1] 5.775
#> 
#> $difference
#> [1] 0.05
#> 
#> $limit
#> [1] 0.0583275
#> 
#> $result
#> [1] "pass"
#> 
#> $passed
#> [1] TRUE
#> 

options(old_opt)
```
