# Core calculation functions.

#' Minimum flow time, in seconds, below which ASTM D445-26 6.1.2/D446-24 8.2.1
#' requires a kinetic energy correction to be applied.
#' @keywords internal
MIN_FLOW_TIME_S <- 200

#' Maximum permissible kinetic energy correction, as a fraction of the
#' measured viscosity, per ASTM D445-26 6.1.2 ("shall not exceed 3.0 % of
#' the measured viscosity").
#' @keywords internal
MAX_KINETIC_ENERGY_CORRECTION_FRACTION <- 0.03

#' Calculate kinematic viscosity from time and calibration constant.
#'
#' Implements the basic relationship of ASTM D445-26 Eq 2 / D446-24 Eq 5,
#' `nu = C * t`, used whenever the flow time is long enough (>= 200 s, or the
#' viscometer-specific minimum in Specifications D446) that the kinetic
#' energy term is negligible. When `time_s` is below `min_flow_time_s`, the
#' kinetic energy correction from D446-24 Eq 6, `nu = C*t - E/t^2`, is applied
#' instead, and the kinetic energy factor, `kinetic_energy_factor`, must be
#' supplied (mm2 * s) because it is viscometer- and geometry-specific and
#' cannot be derived from the flow time and constant alone (D446-24 8.2.3,
#' Eq 7).
#'
#' @param time_s Time in seconds.
#' @param factor Calibration constant (`C`) for the relevant viscometer, in
#'   mm2/s2.
#' @param kinetic_energy_factor Kinetic energy factor `E`, in mm2 * s, used
#'   only when `time_s` is below `min_flow_time_s`. Required in that case;
#'   ignored otherwise.
#' @param min_flow_time_s Minimum flow time, in seconds, below which the
#'   kinetic energy correction is required. Defaults to the general 200 s
#'   minimum from ASTM D445-26 6.1.2/10.2; pass the viscometer- or size-
#'   specific minimum from Specifications D446 when it differs (some sizes
#'   require 250 s, 300 s, 380 s, 600 s, or 1320 s -- see D446-24 Annexes
#'   A1-A3).
#' @return A list with the calculated kinematic viscosity (`viscosity`, in
#'   mm2/s), whether the kinetic energy correction was applied
#'   (`kinetic_energy_correction_applied`), the correction magnitude
#'   (`kinetic_energy_correction`, mm2/s), and the correction as a fraction of
#'   the calculated viscosity (`kinetic_energy_correction_fraction`).
#' @export
calculate_kinematic_viscosity <- function(
  time_s,
  factor,
  kinetic_energy_factor = NA_real_,
  min_flow_time_s = MIN_FLOW_TIME_S
) {
  assert_scalar_numeric(time_s, "time_s")
  assert_scalar_numeric(factor, "factor")
  assert_scalar_numeric(min_flow_time_s, "min_flow_time_s")

  if (time_s <= 0 || factor <= 0) {
    stop(
      "`time_s` and `factor` must be positive numeric values.",
      call. = FALSE
    )
  }

  needs_correction <- time_s < min_flow_time_s

  if (!needs_correction) {
    return(list(
      viscosity = time_s * factor,
      kinetic_energy_correction_applied = FALSE,
      kinetic_energy_correction = 0,
      kinetic_energy_correction_fraction = 0
    ))
  }

  if (is.na(kinetic_energy_factor)) {
    stop(
      sprintf(
        paste(
          "Flow time %.1f s is below the minimum flow time of %.1f s",
          "(ASTM D445-26 6.1.2/10.2). A kinetic energy correction is",
          "required (D446-24 Eq 6), so `kinetic_energy_factor` (E, mm2*s)",
          "must be supplied; it cannot be derived from time and the",
          "calibration constant alone."
        ),
        time_s, min_flow_time_s
      ),
      call. = FALSE
    )
  }
  assert_scalar_numeric(kinetic_energy_factor, "kinetic_energy_factor")

  uncorrected <- time_s * factor
  correction <- kinetic_energy_factor / time_s^2
  viscosity <- uncorrected - correction
  correction_fraction <- if (viscosity != 0) abs(correction) / viscosity else NA_real_

  if (!is.na(correction_fraction) && correction_fraction > MAX_KINETIC_ENERGY_CORRECTION_FRACTION) {
    stop(
      sprintf(
        paste(
          "Kinetic energy correction (%.2f %% of the measured viscosity)",
          "exceeds the 3.0 %% maximum permitted by ASTM D445-26 6.1.2.",
          "Select a viscometer with a narrower capillary/longer flow time."
        ),
        correction_fraction * 100
      ),
      call. = FALSE
    )
  }

  list(
    viscosity = viscosity,
    kinetic_energy_correction_applied = TRUE,
    kinetic_energy_correction = correction,
    kinetic_energy_correction_fraction = if (is.na(correction_fraction)) 0 else correction_fraction
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
      validate_reference_tbl(viscometers, viscometer_required_fields)
      DBI::dbWriteTable(db, "viscometers", viscometers, overwrite = TRUE)
    }
  }

  if (!is.null(sample_types)) {
    if (nrow(sample_types) == 0) {
      DBI::dbExecute(db, "DELETE FROM sample_types")
    } else {
      validate_reference_tbl(sample_types, sample_rule_required_fields)
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
