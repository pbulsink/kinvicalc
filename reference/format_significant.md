# Format a numeric value to at least a given number of significant figures.

Format a numeric value to at least a given number of significant
figures.

## Usage

``` r
format_significant(x, digits = 5)
```

## Arguments

- x:

  A numeric value.

- digits:

  Minimum number of significant figures. ASTM D445-26 15.1 requires 4
  significant figures for a final client-facing report; this package
  defaults to 5 for intermediate/internal reporting so round explicitly
  to 4 when producing a final client report.

## Value

A character string with `x` rounded to `digits` significant figures.

## Examples

``` r
format_significant(5.545, 5)
#> [1] "5.5450"
format_significant(5.545, 4)
#> [1] "5.545"
```
