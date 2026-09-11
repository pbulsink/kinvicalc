# Reporting and app-state helpers.
#
# Reports produced by this package are intermediate/internal reports, not the
# final client-facing report. ASTM D445-26 15.1 requires 4 significant
# figures for a final report; these functions use 5 significant figures by
# default to preserve more precision for internal review. Round explicitly
# to 4 significant figures (e.g. via `format_significant(x, digits = 4)`)
# when producing a final client deliverable.

#' Render a primary sample report.
#'
#' @param result A result object created by `build_sample_result()`.
#' @param output_path Optional output file path for PDF or HTML export.
#' @param digits Minimum significant figures to report (default 5, for
#'   intermediate reports; use 4 for a final client report per ASTM D445-26
#'   15.1).
#' @return Invisibly the result object.
#' @export
render_primary_report <- function(result, output_path = NULL, digits = 5) {
  if (is.null(result) || !inherits(result, "kinvicalc_result")) {
    stop("`result` must be a result created by `build_sample_result()`.", call. = FALSE)
  }

  if (!is.null(output_path)) {
    ke_note <- if (isTRUE(result$kinetic_energy_correction_applied)) {
      "<p>Kinetic energy correction applied (flow time below 200 s).</p>"
    } else {
      ""
    }

    html <- paste0(
      "<html><body><h1>Primary Sample Report (intermediate)</h1>",
      sprintf("<p>Viscometer: %s</p>", result$viscometer_id),
      sprintf("<p>Sample type: %s</p>", result$sample_type),
      sprintf("<p>Temperature: %s C</p>", format_significant(result$analysis_temperature_c, digits)),
      sprintf("<p>Viscosity: %s mm2/s</p>", format_significant(result$kinematic_viscosity_cSt, digits)),
      sprintf("<p>Determinability: %s</p>", result$determinability_result),
      ke_note,
      "</body></html>"
    )
    writeLines(html, con = output_path)
  }

  invisible(result)
}

#' Render a high-density locked sample report.
#'
#' @param results A list of result objects.
#' @param output_path Optional output path.
#' @param digits Minimum significant figures to report (default 5).
#' @return Invisibly the results list.
#' @export
render_high_density_report <- function(results, output_path = NULL, digits = 5) {
  if (is.null(results) || length(results) == 0) {
    stop("`results` must contain at least one result object.", call. = FALSE)
  }

  if (!all(vapply(results, inherits, logical(1), "kinvicalc_result"))) {
    stop("All elements of `results` must be result objects from `build_sample_result()`.", call. = FALSE)
  }

  if (!is.null(output_path)) {
    table_lines <- vapply(results, function(x) {
      sprintf(
        "%s, %s, %s C, %s, %s",
        x$viscometer_id,
        x$sample_type,
        format_significant(x$analysis_temperature_c, digits),
        format_significant(x$kinematic_viscosity_cSt, digits),
        x$determinability_result
      )
    }, character(1))
    writeLines(table_lines, con = output_path)
  }

  invisible(results)
}

#' Lock a result in the session state.
#'
#' @param result A result object.
#' @return The same result object with a locked flag.
#' @export
lock_result <- function(result) {
  if (is.null(result) || !inherits(result, "kinvicalc_result")) {
    stop("`result` must be a result created by `build_sample_result()`.", call. = FALSE)
  }

  result$locked <- TRUE
  result$locked_at <- Sys.time()
  result
}

#' Create a session results table.
#'
#' @param results A list of result objects.
#' @return A tibble summarizing the results.
#' @export
session_results_table <- function(results) {
  if (is.null(results)) {
    return(tibble::tibble())
  }

  tibble::as_tibble(
    lapply(results, function(x) {
      list(
        viscometer_id = x$viscometer_id,
        sample_type = x$sample_type,
        analysis_temperature_c = x$analysis_temperature_c,
        time_1 = x$time_1,
        time_2 = x$time_2,
        viscosity = x$kinematic_viscosity_cSt,
        kinetic_energy_correction_applied = isTRUE(x$kinetic_energy_correction_applied),
        determinability = x$determinability_result,
        locked = isTRUE(x$locked)
      )
    })
  )
}
