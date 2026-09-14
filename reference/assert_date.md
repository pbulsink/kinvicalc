# Assert that a value is a single non-missing Date.

Assert that a value is a single non-missing Date.

## Usage

``` r
assert_date(x, name, fn = NULL)
```

## Arguments

- x:

  Value to check.

- name:

  Character scalar naming `x` in the error message.

- fn:

  Character scalar naming the calling function, used in error messages.
  Defaults to the name of the calling function.

## Value

`TRUE`, invisibly, if `x` passes; otherwise aborts via
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html).
