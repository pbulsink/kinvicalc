# Add or replace a sample type precision rule.

Add or replace a sample type precision rule.

## Usage

``` r
add_sample_type_rule(rule)
```

## Arguments

- rule:

  A sample type rule record (see
  [`validate_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/validate_sample_type_rule.md)
  for required columns).

## Value

The inserted rule.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

add_sample_type_rule(
  tibble::tibble(
    sample_type = "custom_oil",
    metric = "determinability",
    temp_min_c = 40,
    temp_max_c = 40,
    coefficient_a = 0.0040,
    exponent_b = 1,
    offset = 0,
    notes = "Example custom rule"
  )
)
#> # A tibble: 1 × 10
#>   sample_type metric temp_min_c temp_max_c coefficient_a exponent_b offset notes
#>   <chr>       <chr>       <int>      <int>         <dbl>      <int>  <int> <chr>
#> 1 custom_oil  deter…         40         40         0.004          1      0 Exam…
#> # ℹ 2 more variables: created_at <chr>, updated_at <chr>

options(old_opt)
```
