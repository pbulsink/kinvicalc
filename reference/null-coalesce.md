# Null-coalescing infix operator.

Null-coalescing infix operator.

## Usage

``` r
x %||% y
```

## Arguments

- x:

  A value to test.

- y:

  Fallback value returned when `x` is `NULL`.

## Value

`y` if `x` is `NULL`, otherwise `x`.

## Examples

``` r
kinvicalc:::`%||%`(NULL, "default")
#> [1] "default"
kinvicalc:::`%||%`("value", "default")
#> [1] "value"
```
