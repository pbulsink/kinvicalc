# Viscometer registry and calibration factor logic.

#' Validate a viscometer identifier.
#'
#' @param viscometer_id Viscometer ID string.
#' @return TRUE if valid, otherwise FALSE.
#' @export
validate_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id")
  is_valid_viscometer_id(viscometer_id)
}

#' Resolve the calibration factor for a specific bulb and temperature.
#'
#' @param viscometer A validated viscometer record.
#' @param temperature_c Temperature in Celsius.
#' @param bulb Which bulb to resolve: top or bottom.
#' @return Calibration factor for the requested bulb and temperature.
#' @export
resolve_calibration_factor <- function(viscometer, temperature_c, bulb = c("top", "bottom")) {
  bulb <- match.arg(bulb)
  assert_scalar_numeric(temperature_c, "temperature_c")

  if (is.data.frame(viscometer) && nrow(viscometer) == 1) {
    viscometer <- tibble::as_tibble(viscometer)
  } else {
    stop("`viscometer` must be a single-row record.", call. = FALSE)
  }

  required <- c("factor_40_top", "factor_40_bottom", "factor_100_top", "factor_100_bottom")
  for (field in required) {
    if (is.na(viscometer[[field]][1]) || !is.numeric(viscometer[[field]][1])) {
      stop(sprintf("Viscometer is missing a valid factor for '%s'.", field), call. = FALSE)
    }
  }

  if (temperature_c == 40) {
    factor <- if (bulb == "top") viscometer$factor_40_top[1] else viscometer$factor_40_bottom[1]
  } else if (temperature_c == 100) {
    factor <- if (bulb == "top") viscometer$factor_100_top[1] else viscometer$factor_100_bottom[1]
  } else {
    factor_40 <- if (bulb == "top") viscometer$factor_40_top[1] else viscometer$factor_40_bottom[1]
    factor_100 <- if (bulb == "top") viscometer$factor_100_top[1] else viscometer$factor_100_bottom[1]
    weight <- (temperature_c - 40) / (100 - 40)
    factor <- factor_40 + (factor_100 - factor_40) * weight
  }

  if (!is.finite(factor) || is.na(factor)) {
    stop("Resolved calibration factor is not finite.", call. = FALSE)
  }

  factor
}

#' List all viscometers in the local registry.
#'
#' @return A tibble of viscometer records.
#' @export
list_viscometers <- function() {
  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  query <- "SELECT * FROM viscometers ORDER BY viscometer_id"
  tibble::as_tibble(DBI::dbGetQuery(db, query))
}

#' Get one viscometer by identifier.
#'
#' @param viscometer_id A viscometer identifier.
#' @return A one-row tibble for the requested viscometer.
#' @export
get_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id")
  if (!validate_viscometer(viscometer_id)) {
    stop("`viscometer_id` must match the pattern `###-#####`.", call. = FALSE)
  }

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  result <- DBI::dbGetQuery(
    db,
    "SELECT * FROM viscometers WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (nrow(result) == 0) {
    stop(sprintf("No viscometer found for '%s'.", viscometer_id), call. = FALSE)
  }

  tibble::as_tibble(result)
}

#' Add a viscometer record to the local registry.
#'
#' @param viscometer A viscometer record tibble.
#' @return The inserted viscometer record.
#' @export
add_viscometer <- function(viscometer) {
  viscometer <- validate_viscometer_record(viscometer)

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  existing <- DBI::dbGetQuery(
    db,
    "SELECT 1 FROM viscometers WHERE viscometer_id = ?",
    params = list(viscometer$viscometer_id[1])
  )

  if (nrow(existing) > 0) {
    DBI::dbExecute(
      db,
      "UPDATE viscometers SET viscometer_size = ?, serial_number = ?, calibration_date = ?, status = ?, factor_40_top = ?, factor_40_bottom = ?, factor_100_top = ?, factor_100_bottom = ?, added_by = COALESCE(?, added_by), updated_at = CURRENT_TIMESTAMP, notes = COALESCE(?, notes) WHERE viscometer_id = ?",
      params = list(
        viscometer$viscometer_size[1],
        as.character(viscometer$serial_number[1]),
        as.character(viscometer$calibration_date[1]),
        viscometer$status[1],
        viscometer$factor_40_top[1],
        viscometer$factor_40_bottom[1],
        viscometer$factor_100_top[1],
        viscometer$factor_100_bottom[1],
        if ("added_by" %in% names(viscometer)) viscometer$added_by[1] else NA_character_,
        if ("notes" %in% names(viscometer)) viscometer$notes[1] else NA_character_,
        viscometer$viscometer_id[1]
      )
    )
  } else {
    DBI::dbExecute(
      db,
      "INSERT INTO viscometers (viscometer_id, viscometer_size, serial_number, calibration_date, status, factor_40_top, factor_40_bottom, factor_100_top, factor_100_bottom, added_by, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
      params = list(
        viscometer$viscometer_id[1],
        viscometer$viscometer_size[1],
        as.character(viscometer$serial_number[1]),
        as.character(viscometer$calibration_date[1]),
        viscometer$status[1],
        viscometer$factor_40_top[1],
        viscometer$factor_40_bottom[1],
        viscometer$factor_100_top[1],
        viscometer$factor_100_bottom[1],
        if ("added_by" %in% names(viscometer)) viscometer$added_by[1] else NA_character_,
        if ("notes" %in% names(viscometer)) viscometer$notes[1] else NA_character_
      )
    )
  }

  get_viscometer(viscometer$viscometer_id[1])
}

#' Remove a viscometer from the local registry.
#'
#' @param viscometer_id A viscometer identifier.
#' @return Invisibly TRUE when removed.
#' @export
remove_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id")
  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  deleted <- DBI::dbExecute(
    db,
    "DELETE FROM viscometers WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  invisible(deleted > 0)
}
