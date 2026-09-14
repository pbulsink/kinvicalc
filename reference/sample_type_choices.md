# Build a named vector of sample-type choices for UI select inputs.

Reads the distinct sample types currently defined in the local reference
database and names each key with its human-readable label (via
[`format_sample_type_label()`](https://pbulsink.github.io/kinvicalc/reference/format_sample_type_label.md)),
suitable for passing directly to `shiny::selectInput(choices = ...)`.

## Usage

``` r
sample_type_choices()
```

## Value

A named character vector: values are sample-type keys, names are display
labels.
