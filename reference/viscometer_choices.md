# Build a named vector of viscometer choices for UI select inputs.

Reads viscometers from the local registry and names each ID with its
display label (via
[`format_viscometer_label()`](https://pbulsink.github.io/kinvicalc/reference/format_viscometer_label.md)),
suitable for passing directly to `shiny::selectInput(choices = ...)`.

## Usage

``` r
viscometer_choices(include_archived = FALSE)
```

## Arguments

- include_archived:

  If `FALSE` (default), archived viscometers are excluded.

## Value

A named character vector: values are viscometer IDs, names are display
labels. An empty named vector if the registry (post-filtering) is empty.
