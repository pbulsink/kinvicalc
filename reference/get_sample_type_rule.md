# Get a sample-type precision rule.

If no rule is defined for `sample_type` at `analysis_temperature_c` (for
the given `metric`), this falls back to the `"unlisted"` rule set (ASTM
D445-26 12.4.1/11.2.4 fallback limits for materials/temperatures not
explicitly tabulated in Section 17), rather than raising an error. A
rule that exists but is marked unverified (`coefficient_a` is `NA`) is
not silently replaced by the fallback – that still errors, since
transcription of that cell could not be confirmed and using the
"unlisted" limit in its place could mask an ASTM-defined value that
differs from the fallback.

## Usage

``` r
get_sample_type_rule(
  sample_type,
  analysis_temperature_c = 40,
  metric = precision_metrics
)
```

## Arguments

- sample_type:

  Sample type label (see
  [`.default_sample_rules()`](https://pbulsink.github.io/kinvicalc/reference/dot-default_sample_rules.md)
  for the supported identifiers drawn from ASTM D445-26 17.1.1, 17.1.2,
  17.2.1, and 17.2.2).

- analysis_temperature_c:

  Analysis temperature in C.

- metric:

  Which precision metric to retrieve: "determinability",
  "repeatability", or "reproducibility".

## Value

A one-row tibble for the requested rule.

## Examples

``` r
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

get_sample_type_rule("base_oil", 40, metric = "determinability")
#> # A tibble: 1 × 10
#>   sample_type metric temp_min_c temp_max_c coefficient_a exponent_b offset notes
#>   <chr>       <chr>       <int>      <int>         <dbl>      <int>  <int> <chr>
#> 1 base_oil    deter…         40         40        0.0037          1      0 D445…
#> # ℹ 2 more variables: created_at <chr>, updated_at <chr>

options(old_opt)
```
