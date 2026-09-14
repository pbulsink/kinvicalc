# Build the viscometer dropdown choices for the Shiny app.

Build the viscometer dropdown choices for the Shiny app.

## Usage

``` r
viscometer_choices_app(include_archived = FALSE)
```

## Arguments

- include_archived:

  If `FALSE` (default), archived viscometers are excluded from the
  returned choices.

## Value

A named character vector: values are viscometer IDs, names are
`"<id> (size <size>)"` labels (with an `" [archived]"` suffix when
applicable), suitable for `shiny::selectInput(choices = ...)`. An empty
named vector if the registry (post-filtering) is empty.
