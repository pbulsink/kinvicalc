# Build the sample-type dropdown choices for the Shiny app.

Unlike `kinvicalc:::sample_type_choices()` (which reads distinct sample
types from the local reference database), this returns a fixed, curated
ordering of the sample types the app exposes in its UI, with
`"standard"` (the Characterization Laboratory QA/QC reference substance)
listed alongside the ASTM D445-26 material categories.

## Usage

``` r
sample_type_choices_app()
```

## Value

A named character vector: values are sample-type keys, names are display
labels, suitable for `shiny::selectInput(choices = ...)`.
