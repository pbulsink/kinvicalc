# Calculate a precision limit from a rule and a compared value.

Calculate a precision limit from a rule and a compared value.

## Usage

``` r
calculate_precision_limit(rule, average_value)
```

## Arguments

- rule:

  A one-row precision rule tibble (see
  [`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md)).

- average_value:

  The average of the two values being compared, mm2/s.

## Value

The numeric precision limit, mm2/s.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

rule <- get_sample_type_rule("base_oil", 40, metric = "determinability")
kinvicalc:::calculate_precision_limit(rule, average_value = 5.5)
#> [1] 0.02035

options(old_opt)
```
