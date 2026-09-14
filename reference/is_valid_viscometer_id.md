# Check whether a string matches the canonical viscometer ID pattern.

Check whether a string matches the canonical viscometer ID pattern.

## Usage

``` r
is_valid_viscometer_id(x)
```

## Arguments

- x:

  Character vector to test.

## Value

A logical vector the same length as `x`, `TRUE` where the value matches
`NNN-XXXXX` (three digits, hyphen, five alphanumeric characters).

## Examples

``` r
kinvicalc:::is_valid_viscometer_id("200-12345")
#> [1] TRUE
kinvicalc:::is_valid_viscometer_id("not-an-id")
#> [1] FALSE
```
