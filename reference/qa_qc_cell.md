# Render the "QA/QC" cell of the locked-results reporting table.

Standard reference samples (`sample_type == "standard"`) show
determinability, repeatability (r), and reproducibility (R) pass/fail,
each coloured independently (green for pass, red for fail); other sample
types show determinability only.

## Usage

``` r
qa_qc_cell(x)
```

## Arguments

- x:

  A single `kinvicalc_result` (or an equivalent list) with
  `determinability_result`, `sample_type`, and, for standard samples, a
  `standard_check` list produced by
  [`evaluate_standard_check()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_standard_check.md).

## Value

A character scalar of HTML (`<span>`/`<br/>`) for use in a
[`shiny::renderTable()`](https://rdrr.io/pkg/shiny/man/renderTable.html)-rendered
results table.
