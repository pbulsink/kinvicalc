# Save reference data to the local database.

Save reference data to the local database.

## Usage

``` r
save_reference_data(viscometers = NULL, sample_types = NULL)
```

## Arguments

- viscometers:

  A tibble of viscometer records.

- sample_types:

  A tibble of sample-type rules.

## Value

Invisibly TRUE when saved.

## Examples

``` r
# Use a temporary registry so the example does not touch the real
# user-level reference.db.
old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))

save_reference_data(sample_types = kinvicalc:::.default_sample_rules())

options(old_opt)
```
