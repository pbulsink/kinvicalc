# Assert that a data frame has all expected columns.

Assert that a data frame has all expected columns.

## Usage

``` r
validate_reference_tbl(tbl, expected_cols, fn = NULL)
```

## Arguments

- tbl:

  A data frame or tibble to validate.

- expected_cols:

  Character vector of column names that must be present in `tbl`.

- fn:

  Character scalar naming the calling function, used in error messages.
  Defaults to the name of the calling function.

## Value

`tbl`, invisibly, if all expected columns are present; otherwise aborts
via
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html).
