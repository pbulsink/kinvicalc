# Validate a viscometer identifier.

Validate a viscometer identifier.

## Usage

``` r
validate_viscometer(viscometer_id)
```

## Arguments

- viscometer_id:

  Viscometer ID string.

## Value

TRUE if valid, otherwise FALSE.

## Examples

``` r
validate_viscometer("200-12345")
#> [1] TRUE
validate_viscometer("not-an-id")
#> [1] FALSE
```
