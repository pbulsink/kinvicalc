# Load reference data from the local database.

Load reference data from the local database.

## Usage

``` r
load_reference_data()
```

## Value

A list containing viscometers and sample_types.

## Examples

``` r
# Use a temporary registry so the example does not touch the real
# user-level reference.db.
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

load_reference_data()$sample_types
#> # A tibble: 50 × 10
#>    sample_type    metric   temp_min_c temp_max_c coefficient_a exponent_b offset
#>    <chr>          <chr>         <dbl>      <dbl>         <dbl>      <dbl>  <int>
#>  1 additive       determi…        100        100       0.00106        1.1      0
#>  2 additive       repeata…        100        100       0.00192        1.1      0
#>  3 additive       reprodu…        100        100       0.00862        1.1      0
#>  4 base_oil       determi…         40         40       0.0037         1        0
#>  5 base_oil       determi…        100        100       0.0036         1        0
#>  6 base_oil       repeata…         40         40       0.0101         1        0
#>  7 base_oil       repeata…        100        100       0.0085         1        0
#>  8 base_oil       reprodu…         40         40       0.0136         1        0
#>  9 base_oil       reprodu…        100        100       0.019          1        0
#> 10 formulated_oil determi…         40         40       0.0037         1        0
#> # ℹ 40 more rows
#> # ℹ 3 more variables: notes <chr>, created_at <chr>, updated_at <chr>

options(old_opt)
```
