# Evaluate reproducibility between two independent results from different labs.

Per ASTM D445-26 17.2.2, reproducibility compares two independent
results obtained by different operators in different laboratories.

## Usage

``` r
evaluate_reproducibility(
  sample_type,
  analysis_temperature_c,
  result_1,
  result_2
)
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

evaluate_reproducibility(
  sample_type = "base_oil",
  analysis_temperature_c = 40,
  result_1 = 5.80,
  result_2 = 5.70
)
#> $sample_type
#> [1] "base_oil"
#> 
#> $analysis_temperature_c
#> [1] 40
#> 
#> $average_result
#> [1] 5.75
#> 
#> $difference
#> [1] 0.1
#> 
#> $limit
#> [1] 0.0782
#> 
#> $result
#> [1] "fail"
#> 
#> $passed
#> [1] FALSE
#> 

options(old_opt)
```
