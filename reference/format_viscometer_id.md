# Format a viscometer ID

Builds the canonical `NNN-NNNNN` viscometer ID (three-digit size prefix,
hyphen, serial number) used as the primary key throughout the registry.

## Usage

``` r
format_viscometer_id(viscometer_size, serial_number, fn = NULL)
```

## Arguments

- viscometer_size:

  Integer viscometer size number (1-999), per the ASTM viscometer size
  designation used to construct the ID prefix.

- serial_number:

  Character serial number, used as the ID suffix.

- fn:

  Character scalar naming the calling function, used in error messages.
  Defaults to the name of the calling function.

## Value

A character scalar viscometer ID in `NNN-NNNNN` format.

## Examples

``` r
format_viscometer_id(200, "12345")
#> [1] "200-12345"
```
