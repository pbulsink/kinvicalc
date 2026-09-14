# Assert that a value is a single non-empty string.

Assert that a value is a single non-empty string.

## Usage

``` r
assert_string(x, name, allow_na = FALSE, fn = NULL)
```

## Arguments

- x:

  Value to check.

- name:

  Character scalar naming `x` in the error message.

- allow_na:

  If `TRUE`, a single `NA` value passes the check instead of raising an
  error. Defaults to `FALSE`.

- fn:

  Character scalar naming the calling function, used in error messages.
  Defaults to the name of the calling function.

## Value

`TRUE`, invisibly, if `x` passes; otherwise aborts via
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html).
