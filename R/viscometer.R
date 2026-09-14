# Viscometer registry and calibration factor logic.

#' Validate a viscometer identifier.
#'
#' @param viscometer_id Viscometer ID string.
#' @return TRUE if valid, otherwise FALSE.
#' @export
validate_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id", fn = "validate_viscometer")
  is_valid_viscometer_id(viscometer_id)
}

#' Resolve the calibration factor for a specific bulb and temperature.
#'
#' @param viscometer A validated viscometer record.
#' @param temperature_c Temperature in Celsius.
#' @param bulb Which bulb to resolve: top or bottom.
#' @return Calibration factor for the requested bulb and temperature.
#' @export
resolve_calibration_factor <- function(
  viscometer,
  temperature_c,
  bulb = c("top", "bottom")
) {
  bulb <- match.arg(bulb)
  assert_scalar_numeric(
    temperature_c,
    "temperature_c",
    fn = "resolve_calibration_factor"
  )

  if (is.data.frame(viscometer) && nrow(viscometer) == 1) {
    viscometer <- tibble::as_tibble(viscometer)
  } else {
    cli::cli_abort(c(
      "{.fn resolve_calibration_factor}: {.arg viscometer} must be a single-row record.",
      "i" = "Retrieve one viscometer with {.fn get_viscometer} or subset to one row before resolving calibration."
    ))
  }

  required <- c(
    "factor_40_top",
    "factor_40_bottom",
    "factor_100_top",
    "factor_100_bottom"
  )
  for (field in required) {
    if (is.na(viscometer[[field]][1]) || !is.numeric(viscometer[[field]][1])) {
      cli::cli_abort(c(
        "{.fn resolve_calibration_factor}: viscometer is missing a valid numeric factor for {.arg {field}}.",
        "i" = "Populate all factor fields (40/100 C x top/bottom) before resolving the calibration factor."
      ))
    }
  }

  if (temperature_c == 40) {
    factor <- if (bulb == "top") {
      viscometer$factor_40_top[1]
    } else {
      viscometer$factor_40_bottom[1]
    }
  } else if (temperature_c == 100) {
    factor <- if (bulb == "top") {
      viscometer$factor_100_top[1]
    } else {
      viscometer$factor_100_bottom[1]
    }
  } else {
    factor_40 <- if (bulb == "top") {
      viscometer$factor_40_top[1]
    } else {
      viscometer$factor_40_bottom[1]
    }
    factor_100 <- if (bulb == "top") {
      viscometer$factor_100_top[1]
    } else {
      viscometer$factor_100_bottom[1]
    }
    weight <- (temperature_c - 40) / (100 - 40)
    factor <- factor_40 + (factor_100 - factor_40) * weight
  }

  if (!is.finite(factor) || is.na(factor)) {
    cli::cli_abort(c(
      "{.fn resolve_calibration_factor}: resolved calibration factor is not finite.",
      "i" = "Check the stored calibration factors for missing or invalid numeric values."
    ))
  }

  factor
}

#' List all viscometers in the local registry.
#'
#' Includes use counters (`use_count_since_cleaning`, `total_use_count`) and
#' the most recent deep-clean timestamp (`last_deep_cleaned_at`) when available.
#'
#' @return A tibble of viscometer records.
#' @export
list_viscometers <- function() {
  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  query <- "SELECT viscometer_id, viscometer_size, serial_number, status, factor_40_top, factor_40_bottom, factor_100_top, factor_100_bottom, use_count_since_cleaning, total_use_count, last_deep_cleaned_at, archived_at, added_by, notes, created_at, updated_at FROM viscometers ORDER BY viscometer_id"
  tibble::as_tibble(DBI::dbGetQuery(db, query))
}

#' List active viscometers in the local registry.
#'
#' @return A tibble of non-archived viscometer records.
#' @export
list_active_viscometers <- function() {
  viscometers <- list_viscometers()
  if (!"archived_at" %in% names(viscometers)) {
    return(viscometers)
  }
  viscometers[is.na(viscometers$archived_at), ]
}

#' List archived viscometers in the local registry.
#'
#' @return A tibble of archived viscometer records.
#' @export
list_archived_viscometers <- function() {
  viscometers <- list_viscometers()
  if (!"archived_at" %in% names(viscometers)) {
    return(viscometers[0, ])
  }
  viscometers[!is.na(viscometers$archived_at), ]
}

#' Get one viscometer by identifier.
#'
#' @param viscometer_id A viscometer identifier.
#' @return A one-row tibble for the requested viscometer.
#' @export
get_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id", fn = "get_viscometer")
  if (!validate_viscometer(viscometer_id)) {
    cli::cli_abort(c(
      "{.fn get_viscometer}: {.arg viscometer_id} must match {.val ###-#####}.",
      "i" = "Viscometers must be named {.val ###-#####} corresponding to size-serial number."
    ))
  }

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  result <- DBI::dbGetQuery(
    db,
    "SELECT viscometer_id, viscometer_size, serial_number, status, factor_40_top, factor_40_bottom, factor_100_top, factor_100_bottom, use_count_since_cleaning, total_use_count, last_deep_cleaned_at, archived_at, added_by, notes, created_at, updated_at FROM viscometers WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (nrow(result) == 0) {
    cli::cli_abort(c(
      "{.fn get_viscometer}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  tibble::as_tibble(result)
}

#' Add a viscometer record to the local registry.
#'
#' New records initialize `use_count_since_cleaning` and `total_use_count` to 0,
#' and `last_deep_cleaned_at` to `NA`.
#'
#' @param viscometer A viscometer record tibble.
#' @return The inserted viscometer record.
#' @export
add_viscometer <- function(viscometer) {
  viscometer <- validate_viscometer_record(viscometer)
  if (!"archived_at" %in% names(viscometer)) {
    viscometer$archived_at <- NA_character_
  }

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  viscometer$viscometer_id <- format_viscometer_id(
    viscometer$viscometer_size[1],
    viscometer$serial_number[1],
    fn = "add_viscometer"
  )

  existing <- DBI::dbGetQuery(
    db,
    "SELECT 1 FROM viscometers WHERE viscometer_id = ?",
    params = list(viscometer$viscometer_id[1])
  )

  if (nrow(existing) > 0) {
    cli::cli_abort(c(
      "{.fn add_viscometer}: viscometer {.val {viscometer$viscometer_id[1]}} already exists.",
      "i" = "Each viscometer ID (derived from size and serial number) must be unique in the registry."
    ))
  }

  DBI::dbExecute(
    db,
    "INSERT INTO viscometers (viscometer_id, viscometer_size, serial_number, status, factor_40_top, factor_40_bottom, factor_100_top, factor_100_bottom, use_count_since_cleaning, total_use_count, last_deep_cleaned_at, added_by, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, NULL, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
    params = list(
      viscometer$viscometer_id[1],
      viscometer$viscometer_size[1],
      as.character(viscometer$serial_number[1]),
      viscometer$status[1],
      viscometer$factor_40_top[1],
      viscometer$factor_40_bottom[1],
      viscometer$factor_100_top[1],
      viscometer$factor_100_bottom[1],
      if ("added_by" %in% names(viscometer)) {
        viscometer$added_by[1]
      } else {
        NA_character_
      },
      if ("notes" %in% names(viscometer)) {
        viscometer$notes[1]
      } else {
        NA_character_
      }
    )
  )

  get_viscometer(viscometer$viscometer_id[1])
}

#' Update calibration factors for an existing viscometer.
#'
#' Used to correct calibration factors that were entered incorrectly when the
#' viscometer was first added, without disturbing its use counters, creation
#' date, or archive status. If `notes` is left blank, an auto-generated note
#' of the form `"Updated YYYY-MM-DD by <updated_by>"` is recorded so the
#' correction is traceable.
#'
#' @param viscometer_id A viscometer identifier.
#' @param factor_40_top,factor_40_bottom,factor_100_top,factor_100_bottom
#'   Replacement calibration factors.
#' @param notes Optional replacement notes. If `NA` or blank, an
#'   auto-generated "updated" note is recorded instead.
#' @param updated_by Optional name/identifier of the person making the
#'   update, used in the auto-generated note.
#' @return The updated viscometer record.
#' @export
#' @examples
#' \dontrun{
#' update_viscometer_factors(
#'   "007-00007",
#'   factor_40_top = 0.0251,
#'   factor_40_bottom = 0.0251,
#'   factor_100_top = 0.0251,
#'   factor_100_bottom = 0.0251,
#'   updated_by = "jsmith"
#' )
#' }
update_viscometer_factors <- function(
  viscometer_id,
  factor_40_top,
  factor_40_bottom,
  factor_100_top,
  factor_100_bottom,
  notes = NA_character_,
  updated_by = NA_character_
) {
  assert_string(
    viscometer_id,
    "viscometer_id",
    fn = "update_viscometer_factors"
  )
  assert_scalar_numeric(
    factor_40_top,
    "factor_40_top",
    fn = "update_viscometer_factors"
  )
  assert_scalar_numeric(
    factor_40_bottom,
    "factor_40_bottom",
    fn = "update_viscometer_factors"
  )
  assert_scalar_numeric(
    factor_100_top,
    "factor_100_top",
    fn = "update_viscometer_factors"
  )
  assert_scalar_numeric(
    factor_100_bottom,
    "factor_100_bottom",
    fn = "update_viscometer_factors"
  )

  if (is.na(notes) || !nzchar(trimws(notes))) {
    notes <- sprintf(
      "Updated %s by %s",
      as.character(Sys.Date()),
      if (is.na(updated_by) || !nzchar(trimws(updated_by))) {
        "unknown"
      } else {
        trimws(updated_by)
      }
    )
  } else {
    notes <- trimws(notes)
  }

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  updated <- DBI::dbExecute(
    db,
    "UPDATE viscometers
     SET factor_40_top = ?,
         factor_40_bottom = ?,
         factor_100_top = ?,
         factor_100_bottom = ?,
         notes = ?,
         updated_at = CURRENT_TIMESTAMP
     WHERE viscometer_id = ?",
    params = list(
      factor_40_top,
      factor_40_bottom,
      factor_100_top,
      factor_100_bottom,
      notes,
      viscometer_id
    )
  )

  if (updated == 0) {
    cli::cli_abort(c(
      "{.fn update_viscometer_factors}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  get_viscometer(viscometer_id)
}

#' Archive a viscometer in the local registry.
#'
#' @param viscometer_id A viscometer identifier.
#' @return The updated viscometer record.
#' @export
archive_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id", fn = "archive_viscometer")

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  updated <- DBI::dbExecute(
    db,
    "UPDATE viscometers SET archived_at = COALESCE(archived_at, CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (updated == 0) {
    cli::cli_abort(c(
      "{.fn archive_viscometer}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  get_viscometer(viscometer_id)
}

#' Unarchive a viscometer in the local registry.
#'
#' @param viscometer_id A viscometer identifier.
#' @return The updated viscometer record.
#' @export
unarchive_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id", fn = "unarchive_viscometer")

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  updated <- DBI::dbExecute(
    db,
    "UPDATE viscometers SET archived_at = NULL, updated_at = CURRENT_TIMESTAMP WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (updated == 0) {
    cli::cli_abort(c(
      "{.fn unarchive_viscometer}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  get_viscometer(viscometer_id)
}


#' Increment viscometer use counters by one.
#'
#' Records one additional use of a viscometer by incrementing both the
#' `use_count_since_cleaning` and `total_use_count` fields in the local
#' registry.
#'
#' @param viscometer_id A viscometer identifier.
#' @return Invisibly `TRUE` when the counter update succeeds.
#' @export
#' @examples
#' \dontrun{
#' increment_viscometer_use("007-00007")
#' }
increment_viscometer_use <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id", fn = "increment_viscometer_use")

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  updated <- DBI::dbExecute(
    db,
    "UPDATE viscometers
     SET use_count_since_cleaning = COALESCE(use_count_since_cleaning, 0) + 1,
         total_use_count = COALESCE(total_use_count, 0) + 1,
         updated_at = CURRENT_TIMESTAMP
     WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (updated == 0) {
    cli::cli_abort(c(
      "{.fn increment_viscometer_use}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  invisible(TRUE)
}

#' Reset viscometer use count since deep cleaning.
#'
#' Resets the post-cleaning usage counter for a viscometer and records the
#' current time as the most recent deep-clean timestamp.
#'
#' @param viscometer_id A viscometer identifier.
#' @return A one-row tibble with the updated use counters for the viscometer.
#' @export
#' @examples
#' \dontrun{
#' reset_viscometer_use_count("007-00007")
#' }
reset_viscometer_use_count <- function(viscometer_id) {
  assert_string(
    viscometer_id,
    "viscometer_id",
    fn = "reset_viscometer_use_count"
  )

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  updated <- DBI::dbExecute(
    db,
    "UPDATE viscometers
     SET use_count_since_cleaning = 0,
         last_deep_cleaned_at = CURRENT_TIMESTAMP,
         updated_at = CURRENT_TIMESTAMP
     WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (updated == 0) {
    cli::cli_abort(c(
      "{.fn reset_viscometer_use_count}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  get_viscometer_use_summary(viscometer_id)
}

#' Get viscometer use counters.
#'
#' Returns the current use summary for a single viscometer, including the
#' number of uses since the last deep cleaning and the overall lifetime use
#' count.
#'
#' @param viscometer_id A viscometer identifier.
#' @return A one-row tibble with `viscometer_id`, `use_count_since_cleaning`,
#'   `total_use_count`, and `last_deep_cleaned_at`.
#' @export
#' @examples
#' \dontrun{
#' get_viscometer_use_summary("007-00007")
#' }
get_viscometer_use_summary <- function(viscometer_id) {
  assert_string(
    viscometer_id,
    "viscometer_id",
    fn = "get_viscometer_use_summary"
  )

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  result <- DBI::dbGetQuery(
    db,
    "SELECT viscometer_id,
            COALESCE(use_count_since_cleaning, 0) AS use_count_since_cleaning,
            COALESCE(total_use_count, 0) AS total_use_count,
            last_deep_cleaned_at
     FROM viscometers
     WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  if (nrow(result) == 0) {
    cli::cli_abort(c(
      "{.fn get_viscometer_use_summary}: no viscometer found for {.val {viscometer_id}}.",
      "i" = "Check the identifier and add it with {.fn add_viscometer} if it is new."
    ))
  }

  tibble::as_tibble(result)
}

#' Remove a viscometer from the local registry.
#'
#' @param viscometer_id A viscometer identifier.
#' @return Invisibly TRUE when removed.
#' @export
remove_viscometer <- function(viscometer_id) {
  assert_string(viscometer_id, "viscometer_id", fn = "remove_viscometer")
  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  deleted <- DBI::dbExecute(
    db,
    "DELETE FROM viscometers WHERE viscometer_id = ?",
    params = list(viscometer_id)
  )

  invisible(deleted > 0)
}
