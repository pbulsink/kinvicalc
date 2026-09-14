# Format a sample-type key as a human-readable label.

Converts an internal snake_case sample-type key (as stored in the
`sample_types` registry table, e.g. `"base_oil"`) into a title-case
label suitable for display (e.g. `"Base Oil"`).

## Usage

``` r
format_sample_type_label(sample_type)
```

## Arguments

- sample_type:

  Character scalar sample-type key, or `NA`.

## Value

A character scalar label, or `NA_character_` if `sample_type` is `NA`.

## Examples

``` r
kinvicalc:::format_sample_type_label("base_oil")
#> [1] "Base Oil"
kinvicalc:::format_sample_type_label("kerosine_diesel_biodiesel")
#> [1] "Kerosine Diesel Biodiesel"
```
