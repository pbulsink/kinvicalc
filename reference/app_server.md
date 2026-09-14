# Shiny server logic for the `kinvicalc` app.

Wires together the two-flow-time measurement form, calculation and
result locking, the standard-sample QA/QC check, and the viscometer
registry add/update form. Not called directly; used by
[`run_app()`](https://pbulsink.github.io/kinvicalc/reference/run_app.md)
to construct the
[`shiny::shinyApp()`](https://rdrr.io/pkg/shiny/man/shinyApp.html)
object.

## Usage

``` r
app_server(input, output, session)
```

## Arguments

- input, output, session:

  Standard Shiny server arguments.

## Value

Nothing meaningful; called for its side effect of registering reactive
outputs and observers.
