# Default sample-type precision rules, transcribed from ASTM D445-26.

Builds the seed data for the `sample_types` registry table (D445-26
Section 17, Precision and Bias):

- determinability (d): 17.1.1 (table) and 17.1.2 (used in-service oils);
  11.2.4/12.4.1 fallback estimates for materials/temperatures not
  listed.

- repeatability (r): 17.2.1.

- reproducibility (R): 17.2.2.

## Usage

``` r
.default_sample_rules()
```

## Value

A tibble of seed precision rules with columns `sample_type`,
`temp_min_c`, `temp_max_c`, `coefficient_a`, `exponent_b`, `offset`,
`notes`, and `metric`.

## Details

Each rule expresses its limit as a function of the average of the two
compared values, y or x (mm2/s):

`limit = coefficient_a * (average + offset) ^ exponent_b`

covering every functional form used in the standard:

- `"0.0037y"` -\> `coefficient_a = 0.0037`, `exponent_b = 1`,
  `offset = 0`

- `"0.0013(y+1)"` -\> `coefficient_a = 0.0013`, `exponent_b = 1`,
  `offset = 1`

- `"0.00106y^1.1"` -\> `coefficient_a = 0.00106`, `exponent_b = 1.1`,
  `offset = 0`

- a fixed mm2/s value -\> `coefficient_a = value`, `exponent_b = 0`,
  `offset = 0`

Some cells in the standard's repeatability/reproducibility tables for
jet fuels at -40 C, kerosine/diesel/biodiesel fuels and blends at 40 C,
and used in-service formulated oils could not be unambiguously
transcribed from the scanned/OCR'd table layout (columns for several
sample types run together). Those rows are intentionally left with
`coefficient_a = NA` so that
[`get_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/get_sample_type_rule.md)
errors loudly rather than silently using a guessed value; confirm the
correct figures directly against a clean copy of D445-26 Table entries
in 17.2.1/17.2.2 and update via
[`add_sample_type_rule()`](https://pbulsink.github.io/kinvicalc/reference/add_sample_type_rule.md).
