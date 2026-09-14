# Validate a sample-type precision rule.

Validate a sample-type precision rule.

## Usage

``` r
validate_sample_type_rule(rule)
```

## Arguments

- rule:

  A data frame-like record containing precision settings (see
  `precision_metrics` for supported `metric` values).

## Value

The validated rule tibble.

## Examples

``` r
validate_sample_type_rule(
  tibble::tibble(
    sample_type = "base_oil",
    metric = "determinability",
    temp_min_c = 40,
    temp_max_c = 40,
    coefficient_a = 0.0037,
    exponent_b = 1,
    offset = 0
  )
)
#> # A tibble: 1 × 7
#>   sample_type metric       temp_min_c temp_max_c coefficient_a exponent_b offset
#>   <chr>       <chr>             <dbl>      <dbl>         <dbl>      <dbl>  <dbl>
#> 1 base_oil    determinabi…         40         40        0.0037          1      0
```
