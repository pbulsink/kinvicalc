# Round using round-half-to-even (banker's rounding).

All numeric results reported by `kinvicalc` are rounded with round-half-
to-even, matching R's native
[`round()`](https://rdrr.io/r/base/Round.html) behaviour (IEC 60559), so
this is a thin, explicit wrapper used consistently at the point each
reported value is produced.

## Usage

``` r
round_half_even(x, digits = 4)
```

## Arguments

- x:

  A numeric value.

- digits:

  Number of decimal places to round to. Defaults to 4.

## Value

`x` rounded to `digits` decimal places using round-half-to-even.

## Examples

``` r
kinvicalc:::round_half_even(2.5, 0)
#> [1] 2
kinvicalc:::round_half_even(3.14159, 2)
#> [1] 3.14
```
