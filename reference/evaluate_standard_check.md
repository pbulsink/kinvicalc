# Evaluate a measured result against a known standard/expected value.

Repeatability/reproducibility checks against a known Characterization
Laboratory QA/QC Standard Reference Substance value are centred on the
expected value itself, not on the average of the measured result and the
expected value – unlike
[`evaluate_repeatability()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_repeatability.md)/
[`evaluate_reproducibility()`](https://pbulsink.github.io/kinvicalc/reference/evaluate_reproducibility.md),
which compare two independent measured results and so use their average.

## Usage

``` r
evaluate_standard_check(
  sample_type,
  analysis_temperature_c,
  measured_value,
  expected_value,
  metric
)
```

## Arguments

- sample_type:

  Sample type label passed to
  [`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md)
  (typically `"standard"`).

- analysis_temperature_c:

  Analysis temperature in C.

- measured_value:

  The measured kinematic viscosity, mm^2/s.

- expected_value:

  The known/expected kinematic viscosity for the reference substance,
  mm^2/s. The precision limit is centred on this value.

- metric:

  Either `"repeatability"` or `"reproducibility"`, passed to
  [`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md).

## Value

A list with `difference` (absolute difference between measured and
expected values), `limit` (the permitted precision limit), `result`
(`"pass"` or `"fail"`), and `passed` (logical).
