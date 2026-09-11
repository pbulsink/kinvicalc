# Core calculation functions.

#' Minimum flow time, in seconds, below which ASTM D445-26 6.1.2/D446-24 8.2.1
#' flags the result for review (short flow times increase measurement
#' uncertainty).
#' @keywords internal
MIN_FLOW_TIME_S <- 200

#' Calculate kinematic viscosity from time and calibration constant.
#'
#' Implements the basic relationship of ASTM D445-26 Eq 2 / D446-24 Eq 5,
#' `nu = C * t`. No kinetic energy correction is applied by this package;
#' instead, when `time_s` is below `min_flow_time_s`, the result is flagged
#' (`low_flow_time_flag`) so it can be surfaced in reports for operator
#' review, per ASTM D445-26 6.1.2/10.2.
#'
#' @param time_s Time in seconds.
#' @param factor Calibration constant (`C`) for the relevant viscometer, in
#'   mm2/s2.
#' @param min_flow_time_s Minimum flow time, in seconds, below which the
#'   result is flagged. Defaults to the general 200 s minimum from ASTM
#'   D445-26 6.1.2/10.2; pass the viscometer- or size-specific minimum from
#'   Specifications D446 when it differs (some sizes require 250 s, 300 s,
#'   380 s, 600 s, or 1320 s -- see D446-24 Annexes A1-A3).
#' @return A list with the calculated kinematic viscosity (`viscosity`, in
#'   mm2/s) and whether the flow time is below the minimum
#'   (`low_flow_time_flag`).
#' @export
calculate_kinematic_viscosity <- function(
  time_s,
  factor,
  min_flow_time_s = MIN_FLOW_TIME_S
) {
  assert_scalar_numeric(time_s, "time_s", fn = "calculate_kinematic_viscosity")
  assert_scalar_numeric(factor, "factor", fn = "calculate_kinematic_viscosity")
  assert_scalar_numeric(
    min_flow_time_s,
    "min_flow_time_s",
    fn = "calculate_kinematic_viscosity"
  )

  if (time_s <= 0 || factor <= 0) {
    cli::cli_abort(c(
      "{.fn calculate_kinematic_viscosity}: {.arg time_s} and {.arg factor} must be positive.",
      "i" = "Use measured flow time in seconds greater than 0 and a calibrated viscometer factor greater than 0."
    ))
  }

  list(
    viscosity = round_half_even(time_s * factor),
    low_flow_time_flag = time_s < min_flow_time_s
  )
}

#' Get the local SQLite reference database connection.
#'
#' @return An open DBI connection.
#' @keywords internal
reference_db_connection <- function() {
  db_path <- .default_reference_db()
  db <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  DBI::dbExecute(
    db,
    "CREATE TABLE IF NOT EXISTS viscometers (
      viscometer_id TEXT PRIMARY KEY,
      viscometer_size NUMERIC,
      serial_number TEXT,
      calibration_date TEXT,
      status TEXT,
      factor_40_top NUMERIC,
      factor_40_bottom NUMERIC,
      factor_100_top NUMERIC,
      factor_100_bottom NUMERIC,
      use_count_since_cleaning INTEGER DEFAULT 0,
      total_use_count INTEGER DEFAULT 0,
      last_deep_cleaned_at TEXT,
      archived_at TEXT,
      added_by TEXT,
      notes TEXT,
      created_at TEXT,
      updated_at TEXT
    )"
  )

  DBI::dbExecute(
    db,
    "CREATE TABLE IF NOT EXISTS sample_types (
      sample_type TEXT,
      metric TEXT,
      temp_min_c NUMERIC,
      temp_max_c NUMERIC,
      coefficient_a NUMERIC,
      exponent_b NUMERIC,
      offset NUMERIC,
      notes TEXT,
      created_at TEXT,
      updated_at TEXT,
      PRIMARY KEY (sample_type, metric, temp_min_c, temp_max_c)
    )"
  )

  viscometer_cols <- DBI::dbGetQuery(db, "PRAGMA table_info(viscometers)")$name
  if (!"use_count_since_cleaning" %in% viscometer_cols) {
    DBI::dbExecute(
      db,
      "ALTER TABLE viscometers ADD COLUMN use_count_since_cleaning INTEGER DEFAULT 0"
    )
  }
  if (!"total_use_count" %in% viscometer_cols) {
    DBI::dbExecute(
      db,
      "ALTER TABLE viscometers ADD COLUMN total_use_count INTEGER DEFAULT 0"
    )
  }
  if (!"last_deep_cleaned_at" %in% viscometer_cols) {
    DBI::dbExecute(
      db,
      "ALTER TABLE viscometers ADD COLUMN last_deep_cleaned_at TEXT"
    )
  }
  if (!"archived_at" %in% viscometer_cols) {
    DBI::dbExecute(
      db,
      "ALTER TABLE viscometers ADD COLUMN archived_at TEXT"
    )
  }

  sample_rule_count <- DBI::dbGetQuery(
    db,
    "SELECT COUNT(*) AS n FROM sample_types"
  )$n
  if (sample_rule_count == 0) {
    DBI::dbWriteTable(
      db,
      "sample_types",
      .default_sample_rules(),
      append = TRUE,
      overwrite = FALSE
    )
  }

  db
}

#' Save reference data to the local database.
#'
#' @param viscometers A tibble of viscometer records.
#' @param sample_types A tibble of sample-type rules.
#' @return Invisibly TRUE when saved.
#' @export
save_reference_data <- function(viscometers = NULL, sample_types = NULL) {
  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  if (!is.null(viscometers)) {
    if (nrow(viscometers) == 0) {
      DBI::dbExecute(db, "DELETE FROM viscometers")
    } else {
      validate_reference_tbl(
        viscometers,
        viscometer_required_fields,
        fn = "save_reference_data"
      )

      if (!"use_count_since_cleaning" %in% names(viscometers)) {
        viscometers$use_count_since_cleaning <- 0L
      }
      if (!"total_use_count" %in% names(viscometers)) {
        viscometers$total_use_count <- 0L
      }
      if (!"last_deep_cleaned_at" %in% names(viscometers)) {
        viscometers$last_deep_cleaned_at <- NA_character_
      }
      if (!"archived_at" %in% names(viscometers)) {
        viscometers$archived_at <- NA_character_
      }

      DBI::dbWriteTable(db, "viscometers", viscometers, overwrite = TRUE)
    }
  }

  if (!is.null(sample_types)) {
    if (nrow(sample_types) == 0) {
      DBI::dbExecute(db, "DELETE FROM sample_types")
    } else {
      validate_reference_tbl(
        sample_types,
        sample_rule_required_fields,
        fn = "save_reference_data"
      )
      DBI::dbWriteTable(db, "sample_types", sample_types, overwrite = TRUE)
    }
  }

  invisible(TRUE)
}

#' Load reference data from the local database.
#'
#' @return A list containing viscometers and sample_types.
#' @export
load_reference_data <- function() {
  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  viscometers <- tibble::as_tibble(DBI::dbGetQuery(
    db,
    "SELECT * FROM viscometers ORDER BY viscometer_id"
  ))
  sample_types <- tibble::as_tibble(DBI::dbGetQuery(
    db,
    "SELECT * FROM sample_types ORDER BY sample_type, metric, temp_min_c"
  ))

  if (nrow(viscometers) == 0) {
    viscometers <- tibble::tibble()
  }
  if (nrow(sample_types) == 0) {
    sample_types <- .default_sample_rules()
    save_reference_data(
      viscometers = tibble::tibble(),
      sample_types = sample_types
    )
  }

  list(viscometers = viscometers, sample_types = sample_types)
}
