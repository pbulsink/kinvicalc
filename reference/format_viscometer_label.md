# Format a single-row viscometer tibble as a display label.

Format a single-row viscometer tibble as a display label.

## Usage

``` r
format_viscometer_label(viscometer)
```

## Arguments

- viscometer:

  A single-row viscometer tibble (as returned by
  [`get_viscometer()`](https://pbulsink.github.io/kinvicalc/reference/get_viscometer.md)
  or a row of
  [`list_viscometers()`](https://pbulsink.github.io/kinvicalc/reference/list_viscometers.md)),
  used for its `viscometer_id`, `viscometer_size`, and `archived_at`
  fields.

## Value

A character scalar label, e.g. `"001-00001 (size 1)"`, with an
`" [archived]"` suffix when the viscometer is archived.
