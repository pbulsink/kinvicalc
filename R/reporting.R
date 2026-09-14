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
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' add_viscometer(
#'   build_viscometer_record(
#'     viscometer_size = 1,
#'     serial_number = "00001",
#'     factor_40_top = 0.025,
#'     factor_40_bottom = 0.029,
#'     factor_100_top = 0.016,
#'     factor_100_bottom = 0.018
#'   )
#' )
#' result <- build_sample_result(
#'   viscometer_id = "001-00001",
#'   sample_type = "unlisted",
#'   analysis_temperature_c = 40,
#'   time_1 = 232,
#'   time_2 = 200
#' )
#'
#' # Print to console (no output_path -> no file written)
#' render_primary_report(result)
#'
#' # Write an HTML report to a file
#' report_path <- tempfile(fileext = ".html")
#' render_primary_report(result, output_path = report_path)
#'
#' options(old_opt)
render_primary_report <- function(result, output_path = NULL, digits = 5) {
  if (is.null(result) || !inherits(result, "kinvicalc_result")) {
    cli::cli_abort(c(
      "{.fn render_primary_report}: {.arg result} must be created by {.fn build_sample_result}.",
      "i" = "Pass a kinvicalc result object returned by {.fn build_sample_result}."
    ))
  }

  if (!is.null(output_path)) {
    low_time_note <- if (isTRUE(result$low_flow_time_flag)) {
      "<p><strong>Flagged:</strong> flow time below 200 s -- review measurement (ASTM D445-26 6.1.2/10.2).</p>"
    } else {
      ""
    }

    sample_id_note <- if (
      !is.null(result$sample_id) && !is.na(result$sample_id)
    ) {
      sprintf("<p>Sample: %s</p>", result$sample_id)
    } else {
      ""
    }
    operator_note <- if (!is.null(result$operator) && !is.na(result$operator)) {
      sprintf("<p>Operator: %s</p>", result$operator)
    } else {
      ""
    }
    created_at_note <- if (!is.null(result$created_at)) {
      sprintf(
        "<p>Date/time: %s</p>",
        format(result$created_at, "%Y-%m-%d %H:%M:%S")
      )
    } else {
      ""
    }

    html <- paste0(
      "<html><body><h1>Primary Sample Report (intermediate)</h1>",
      sample_id_note,
      operator_note,
      created_at_note,
      sprintf("<p>Viscometer: %s</p>", result$viscometer_id),
      sprintf(
        "<p>Sample type: %s</p>",
        format_sample_type_label(result$sample_type)
      ),
      sprintf(
        "<p>Temperature: %s \u00b0C</p>",
        format_significant(result$analysis_temperature_c, digits)
      ),
      sprintf(
        "<p>Viscosity: %s mm\u00B2/s</p>",
        format_significant(result$kinematic_viscosity_cSt, digits)
      ),
      sprintf("<p>Determinability: %s</p>", result$determinability_result),
      low_time_note,
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
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' add_viscometer(
#'   build_viscometer_record(
#'     viscometer_size = 1,
#'     serial_number = "00001",
#'     factor_40_top = 0.025,
#'     factor_40_bottom = 0.029,
#'     factor_100_top = 0.016,
#'     factor_100_bottom = 0.018
#'   )
#' )
#' result <- build_sample_result(
#'   viscometer_id = "001-00001",
#'   sample_type = "unlisted",
#'   analysis_temperature_c = 40,
#'   time_1 = 232,
#'   time_2 = 200
#' )
#'
#' render_high_density_report(list(result))
#'
#' options(old_opt)
render_high_density_report <- function(
  results,
  output_path = NULL,
  digits = 5
) {
  if (is.null(results) || length(results) == 0) {
    cli::cli_abort(c(
      "{.fn render_high_density_report}: {.arg results} must contain at least one result object.",
      "i" = "Provide a non-empty list of objects returned by {.fn build_sample_result}."
    ))
  }

  if (!all(vapply(results, inherits, logical(1), "kinvicalc_result"))) {
    cli::cli_abort(c(
      "{.fn render_high_density_report}: all elements of {.arg results} must be objects from {.fn build_sample_result}.",
      "i" = "Validate each list element before rendering and remove non-kinvicalc entries."
    ))
  }

  if (!is.null(output_path)) {
    table_lines <- vapply(
      results,
      function(x) {
        flag <- if (isTRUE(x$low_flow_time_flag)) {
          " [FLAG: flow time < 200 s]"
        } else {
          ""
        }
        sprintf(
          "%s, %s, %s, %s \u00b0C, %s, %s%s",
          x$viscometer_id,
          if (!is.null(x$sample_id) && !is.na(x$sample_id)) {
            x$sample_id
          } else {
            "(no sample id)"
          },
          format_sample_type_label(x$sample_type),
          format_significant(x$analysis_temperature_c, digits),
          format_significant(x$kinematic_viscosity_cSt, digits),
          x$determinability_result,
          flag
        )
      },
      character(1)
    )
    writeLines(table_lines, con = output_path)
  }

  invisible(results)
}

#' Lock a result in the session state.
#'
#' @param result A result object.
#' @return The same result object with a locked flag.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' add_viscometer(
#'   build_viscometer_record(
#'     viscometer_size = 1,
#'     serial_number = "00001",
#'     factor_40_top = 0.025,
#'     factor_40_bottom = 0.029,
#'     factor_100_top = 0.016,
#'     factor_100_bottom = 0.018
#'   )
#' )
#' result <- build_sample_result(
#'   viscometer_id = "001-00001",
#'   sample_type = "unlisted",
#'   analysis_temperature_c = 40,
#'   time_1 = 232,
#'   time_2 = 200
#' )
#'
#' locked <- lock_result(result)
#' locked$locked
#'
#' options(old_opt)
lock_result <- function(result) {
  if (is.null(result) || !inherits(result, "kinvicalc_result")) {
    cli::cli_abort(c(
      "{.fn lock_result}: {.arg result} must be created by {.fn build_sample_result}.",
      "i" = "Only lock validated kinvicalc result objects."
    ))
  }

  increment_viscometer_use(result$viscometer_id)

  result$locked <- TRUE
  result$locked_at <- Sys.time()
  result
}

#' Create a session results table.
#'
#' @param results A list of result objects.
#' @return A tibble summarizing the results.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' add_viscometer(
#'   build_viscometer_record(
#'     viscometer_size = 1,
#'     serial_number = "00001",
#'     factor_40_top = 0.025,
#'     factor_40_bottom = 0.029,
#'     factor_100_top = 0.016,
#'     factor_100_bottom = 0.018
#'   )
#' )
#' result <- build_sample_result(
#'   viscometer_id = "001-00001",
#'   sample_type = "unlisted",
#'   analysis_temperature_c = 40,
#'   time_1 = 232,
#'   time_2 = 200
#' )
#'
#' session_results_table(list(result))
#'
#' options(old_opt)
session_results_table <- function(results) {
  if (is.null(results)) {
    return(tibble::tibble())
  }

  rows <- lapply(results, function(x) {
    tibble::tibble(
      operator = if (!is.null(x$operator)) x$operator else NA_character_,
      sample_id = if (!is.null(x$sample_id)) x$sample_id else NA_character_,
      viscometer_id = x$viscometer_id,
      sample_type = x$sample_type,
      analysis_temperature_c = x$analysis_temperature_c,
      time_1 = x$time_1,
      time_2 = x$time_2,
      viscosity = x$kinematic_viscosity_cSt,
      low_flow_time_flag = isTRUE(x$low_flow_time_flag),
      determinability = x$determinability_result,
      locked = isTRUE(x$locked),
      created_at = if (!is.null(x$created_at)) x$created_at else as.POSIXct(NA)
    )
  })

  tibble::as_tibble(do.call(rbind, rows))
}
