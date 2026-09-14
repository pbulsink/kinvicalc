# Resolve the path to the local SQLite reference database.

Returns the user-level path used to store the viscometer registry and
sample-type precision rules. The path can be overridden (for example, to
point at a temporary database in examples, tests, or a rendered README/
vignette) by setting `options(kinvicalc.reference_db_path = <path>)`.

## Usage

``` r
.default_reference_db()
```

## Value

A character scalar file path. Does not guarantee the file exists;
[`reference_db_connection()`](https://pbulsink.github.io/kinvicalc/reference/reference_db_connection.md)
creates it (and its parent directory) lazily on first connection.
