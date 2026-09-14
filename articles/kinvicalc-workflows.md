# kinvicalc workflows

This vignette walks through the package workflow end to end: register a
viscometer, calculate a kinematic viscosity result, and render the
report that a lab operator would review.

The examples use a temporary registry so the vignette builds the same
way in a clean package check and in an interactive session.

## Register a viscometer

Before any calculation can run, the registry needs a viscometer record
with a calibrated constant for each temperature used by the workflow.

``` r

viscometer <- tibble::tibble(
  viscometer_id = "001-00001",
  viscometer_size = 1,
  serial_number = "00001",
  calibration_date = as.Date("2024-01-01"),
  status = "active",
  factor_40_top = 0.025,
  factor_40_bottom = 0.029,
  factor_100_top = 0.016,
  factor_100_bottom = 0.018
)

add_viscometer(viscometer)
```

    ## # A tibble: 1 × 16
    ##   viscometer_id viscometer_size serial_number status factor_40_top
    ##   <chr>                   <int> <chr>         <chr>          <dbl>
    ## 1 001-00001                   1 00001         active         0.025
    ## # ℹ 11 more variables: factor_40_bottom <dbl>, factor_100_top <dbl>,
    ## #   factor_100_bottom <dbl>, use_count_since_cleaning <int>,
    ## #   total_use_count <int>, last_deep_cleaned_at <chr>, archived_at <chr>,
    ## #   added_by <chr>, notes <chr>, created_at <chr>, updated_at <chr>

The inserted record is returned from the registry, which makes it easy
to confirm that the identifier, factors, and status were stored as
expected.

## Correct a viscometer’s calibration factors

If a viscometer’s factors were entered incorrectly,
[`update_viscometer_factors()`](https://pbulsink.github.io/kinvicalc/reference/update_viscometer_factors.md)
corrects them in place without disturbing the record’s identifier,
creation date, use counters, or archive status.

``` r

update_viscometer_factors(
  "001-00001",
  factor_40_top = 0.0251,
  factor_40_bottom = 0.0291,
  factor_100_top = 0.0161,
  factor_100_bottom = 0.0181,
  updated_by = "jsmith"
)
```

    ## # A tibble: 1 × 16
    ##   viscometer_id viscometer_size serial_number status factor_40_top
    ##   <chr>                   <int> <chr>         <chr>          <dbl>
    ## 1 001-00001                   1 00001         active        0.0251
    ## # ℹ 11 more variables: factor_40_bottom <dbl>, factor_100_top <dbl>,
    ## #   factor_100_bottom <dbl>, use_count_since_cleaning <int>,
    ## #   total_use_count <int>, last_deep_cleaned_at <chr>, archived_at <chr>,
    ## #   added_by <chr>, notes <chr>, created_at <chr>, updated_at <chr>

If `notes` is left unspecified (or blank), the update is recorded
automatically as `"Updated <date> by <updated_by>"` so the correction
stays traceable; pass an explicit `notes` value to record a different
reason instead. In the Shiny app (`R/app.R`), entering a viscometer size
and serial number that already exist in the registry changes the “Add to
registry” button to “Update Viscometer Factors” and prompts for
confirmation before applying the change, calling this same function
under the hood.

## Calculate a sample result

A sample result uses two flow-time measurements from the same
viscometer. The package resolves the calibration factor at the analysis
temperature, calculates each determination, and checks whether the pair
satisfies the determinability criterion.

``` r

result <- build_sample_result(
  viscometer_id = "001-00001",
  sample_type = "base_oil",
  analysis_temperature_c = 40,
  time_1 = 200,
  time_2 = 210
)
```

    ## Warning: `build_sample_result()`: determinability check failed for viscometer
    ## "001-00001".
    ## • Observed difference: 1.0910 mm²/s.
    ## • Determinability limit: 0.020592 mm²/s.
    ## ℹ Per ASTM D445-26 11.2.3/12.4.1, repeat flow-time measurements after cleaning
    ##   and drying the viscometer before reporting a final result.

``` r

result
```

    ## $viscometer_id
    ## [1] "001-00001"
    ## 
    ## $viscometer_size
    ## [1] 1
    ## 
    ## $sample_type
    ## [1] "base_oil"
    ## 
    ## $analysis_temperature_c
    ## [1] 40
    ## 
    ## $time_1
    ## [1] 200
    ## 
    ## $time_2
    ## [1] 210
    ## 
    ## $factor
    ## function (x = character(), levels, labels = levels, exclude = NA, 
    ##     ordered = is.ordered(x), nmax = NA) 
    ## {
    ##     if (is.null(x)) 
    ##         x <- character()
    ##     nx <- names(x)
    ##     matchAsChar <- is.object(x) || !(is.character(x) || is.integer(x) || 
    ##         is.logical(x))
    ##     if (missing(levels)) {
    ##         y <- unique(x, nmax = nmax)
    ##         ind <- order(y)
    ##         if (matchAsChar) 
    ##             y <- as.character(y)
    ##         levels <- unique(y[ind])
    ##     }
    ##     force(ordered)
    ##     if (matchAsChar) 
    ##         x <- as.character(x)
    ##     levels <- levels[is.na(match(levels, exclude))]
    ##     f <- match(x, levels)
    ##     if (!is.null(nx)) 
    ##         names(f) <- nx
    ##     if (missing(labels)) {
    ##         levels(f) <- as.character(levels)
    ##     }
    ##     else {
    ##         nlab <- length(labels)
    ##         if (nlab == length(levels)) {
    ##             nlevs <- unique(xlevs <- as.character(labels))
    ##             at <- attributes(f)
    ##             at$levels <- nlevs
    ##             f <- match(xlevs, nlevs)[f]
    ##             attributes(f) <- at
    ##         }
    ##         else if (nlab == 1L) 
    ##             levels(f) <- paste0(labels, seq_along(levels))
    ##         else stop(gettextf("invalid 'labels'; length %d should be 1 or %d", 
    ##             nlab, length(levels)), domain = NA)
    ##     }
    ##     class(f) <- c(if (ordered) "ordered", "factor")
    ##     f
    ## }
    ## <bytecode: 0x5654b6db8560>
    ## <environment: namespace:base>
    ## 
    ## $low_flow_time_flag
    ## [1] FALSE
    ## 
    ## $kinematic_viscosity_1_cSt
    ## [1] 5.02
    ## 
    ## $kinematic_viscosity_2_cSt
    ## [1] 6.111
    ## 
    ## $kinematic_viscosity_cSt
    ## [1] 5.5655
    ## 
    ## $determinability_difference
    ## [1] 1.091
    ## 
    ## $determinability_result
    ## [1] "fail"
    ## 
    ## $determinability_limit
    ## [1] 0.0206
    ## 
    ## $operator
    ## [1] NA
    ## 
    ## $sample_id
    ## [1] NA
    ## 
    ## $notes
    ## [1] NA
    ## 
    ## $created_at
    ## [1] "2026-09-14 15:22:17 UTC"
    ## 
    ## attr(,"class")
    ## [1] "kinvicalc_result" "list"

This example produces a passed result with a single reported viscosity
and a shared determinability limit. If either flow time is below the
method minimum, the result is still returned but is flagged for review.

## Render a report

The report helpers format the calculation for a lab record or
client-facing summary. In an interactive session,
[`render_primary_report()`](https://pbulsink.github.io/kinvicalc/reference/render_primary_report.md)
opens the HTML output directly.

``` r

render_primary_report(result)
```

The same workflow is used in scripts, tests, and the Shiny app, so
keeping this example current is a good check that the package API still
fits the intended workflow.

## Summary

`kinvicalc` centers the workflow around a local viscometer registry, a
pair of flow-time measurements, and a reportable result object. If this
vignette builds successfully, the main package path is working end to
end.
