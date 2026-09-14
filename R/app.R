#' Format a sample type code as a human-readable label.
#'
#' @param sample_type A sample type code.
#' @export
format_sample_type_label_app <- function(sample_type) {
  tools::toTitleCase(gsub("_", " ", sample_type, fixed = TRUE))
}

#' Format a sample type code as a human-readable label.
#'
#' @param sample_type A sample type code.
#' @return A character scalar title-case label, e.g. `"base_oil"` becomes
#'   `"Base Oil"`.
#' @export
#' @examples
#' format_sample_type_label_app("base_oil")
format_sample_type_label_app <- function(sample_type) {
  tools::toTitleCase(gsub("_", " ", sample_type, fixed = TRUE))
}

#' Build the sample-type dropdown choices for the Shiny app.
#'
#' Unlike `kinvicalc:::sample_type_choices()` (which reads distinct sample
#' types from the local reference database), this returns a fixed,
#' curated ordering of the sample types the app exposes in its UI, with
#' `"standard"` (the Characterization Laboratory QA/QC reference substance)
#' listed alongside the ASTM D445-26 material categories.
#'
#' @return A named character vector: values are sample-type keys, names are
#'   display labels, suitable for `shiny::selectInput(choices = ...)`.
#' @keywords internal
sample_type_choices_app <- function() {
  stats::setNames(
    c(
      "kerosine_diesel_biodiesel",
      "jet_fuel",
      "unlisted",
      "standard",
      "additive",
      "base_oil",
      "formulated_oil",
      "gas_oil",
      "petroleum_wax",
      "residual_fuel_oil",
      "used_inservice_formulated_oil"
    ),
    c(
      "Kerosine, Diesel, and Biodiesel",
      "Jet Fuel",
      "Unlisted",
      "Standard Reference Material",
      "Additive",
      "Base Oil",
      "Formulated Oil",
      "Gas Oil",
      "Petroleum Wax",
      "Residual Fuel Oil",
      "Used In-service Formulated Oil"
    )
  )
}

#' Build the viscometer dropdown choices for the Shiny app.
#'
#' @param include_archived If `FALSE` (default), archived viscometers are
#'   excluded from the returned choices.
#' @return A named character vector: values are viscometer IDs, names are
#'   `"<id> (size <size>)"` labels (with an `" [archived]"` suffix when
#'   applicable), suitable for `shiny::selectInput(choices = ...)`. An empty
#'   named vector if the registry (post-filtering) is empty.
#' @keywords internal
viscometer_choices_app <- function(include_archived = FALSE) {
  viscometers <- kinvicalc::list_viscometers()
  if (nrow(viscometers) == 0) {
    return(stats::setNames(character(0), character(0)))
  }

  archived <- if ("archived_at" %in% names(viscometers)) {
    !is.na(viscometers$archived_at)
  } else {
    rep(FALSE, nrow(viscometers))
  }
  keep <- include_archived | !archived
  viscometers <- viscometers[keep, , drop = FALSE]
  archived <- archived[keep]

  if (nrow(viscometers) == 0) {
    return(stats::setNames(character(0), character(0)))
  }

  labels <- sprintf(
    "%s (size %s)%s",
    viscometers$viscometer_id,
    viscometers$viscometer_size,
    ifelse(archived, " [archived]", "")
  )
  stats::setNames(viscometers$viscometer_id, labels)
}

#' Null-coalescing infix operator.
#'
#' @param x A value to test.
#' @param y Fallback value returned when `x` is `NULL`.
#' @return `y` if `x` is `NULL`, otherwise `x`.
#' @name null-coalesce
#' @keywords internal
#' @examples
#' kinvicalc:::`%||%`(NULL, "default")
#' kinvicalc:::`%||%`("value", "default")
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Evaluate a measured result against a known standard/expected value.
#'
#' Repeatability/reproducibility checks against a known Characterization
#' Laboratory QA/QC Standard Reference Substance value are centred on the
#' expected value itself, not on the average of the measured result and the
#' expected value -- unlike `evaluate_repeatability()`/
#' `evaluate_reproducibility()`, which compare two independent measured
#' results and so use their average.
#'
#' @param sample_type Sample type label passed to `get_sample_type_rule()`
#'   (typically `"standard"`).
#' @param analysis_temperature_c Analysis temperature in C.
#' @param measured_value The measured kinematic viscosity, mm^2/s.
#' @param expected_value The known/expected kinematic viscosity for the
#'   reference substance, mm^2/s. The precision limit is centred on this
#'   value.
#' @param metric Either `"repeatability"` or `"reproducibility"`, passed to
#'   `get_sample_type_rule()`.
#' @return A list with `difference` (absolute difference between measured and
#'   expected values), `limit` (the permitted precision limit), `result`
#'   (`"pass"` or `"fail"`), and `passed` (logical).
#' @keywords internal
evaluate_standard_check <- function(
  sample_type,
  analysis_temperature_c,
  measured_value,
  expected_value,
  metric
) {
  rule <- kinvicalc::get_sample_type_rule(
    sample_type,
    analysis_temperature_c,
    metric = metric
  )
  diff <- abs(measured_value - expected_value)
  limit <- kinvicalc:::calculate_precision_limit(rule, expected_value)
  passed <- diff <= limit

  list(
    difference = diff,
    limit = limit,
    result = if (passed) "pass" else "fail",
    passed = passed
  )
}

#' Render the "QA/QC" cell of the locked-results reporting table.
#'
#' Standard reference samples (`sample_type == "standard"`) show
#' determinability, repeatability (r), and reproducibility (R) pass/fail,
#' each coloured independently (green for pass, red for fail); other sample
#' types show determinability only.
#'
#' @param x A single `kinvicalc_result` (or an equivalent list) with
#'   `determinability_result`, `sample_type`, and, for standard samples, a
#'   `standard_check` list produced by `evaluate_standard_check()`.
#' @return A character scalar of HTML (`<span>`/`<br/>`) for use in a
#'   `shiny::renderTable()`-rendered results table.
#' @keywords internal
qa_qc_cell <- function(x) {
  pass_fail_span <- function(label, passed) {
    colour <- if (passed) "#1a7f37" else "#c0392b"
    sprintf(
      "<span style='color: %s;'>%s: %s</span>",
      colour,
      label,
      if (passed) "Pass" else "Fail"
    )
  }

  determ_passed <- identical(x$determinability_result, "pass")
  lines <- pass_fail_span("Determ", determ_passed)

  if (identical(x$sample_type, "standard") && !is.null(x$standard_check)) {
    check <- x$standard_check
    lines <- c(
      lines,
      pass_fail_span("r", isTRUE(check$repeatability$passed)),
      pass_fail_span("R", isTRUE(check$reproducibility$passed))
    )
  }

  paste(lines, collapse = "<br/>")
}

#' Shiny server logic for the `kinvicalc` app.
#'
#' Wires together the two-flow-time measurement form, calculation and result
#' locking, the standard-sample QA/QC check, and the viscometer registry
#' add/update form. Not called directly; used by `run_app()` to construct the
#' `shiny::shinyApp()` object.
#'
#' @param input,output,session Standard Shiny server arguments.
#' @return Nothing meaningful; called for its side effect of registering
#'   reactive outputs and observers.
#' @keywords internal
app_server <- function(input, output, session) {
  result <- shiny::reactiveVal(NULL)
  standard_check <- shiny::reactiveVal(NULL)
  locked_results <- shiny::reactiveVal(list())
  maintenance_message <- shiny::reactiveVal("No maintenance action yet.")
  maintenance_refresh <- shiny::reactiveVal(0L)
  lock_message <- shiny::reactiveVal(NULL)

  bump_maintenance_refresh <- function() {
    maintenance_refresh(maintenance_refresh() + 1L)
  }

  set_maintenance_message <- function(message) {
    maintenance_message(message)
    bump_maintenance_refresh()
  }

  # Reactive expression, rather than an action-button handler, so the
  # calculation and "meets determinability" status update live as the
  # operator types times/IDs, instead of waiting for a "Calculate" click.
  calc_attempt <- shiny::reactive({
    user_id <- trimws(input$user_id %||% "")
    sample_id <- trimws(input$sample_id %||% "")

    is_standard <- identical(input$sample_type, "standard")

    missing_fields <- c(
      if (!nzchar(user_id)) "user ID",
      if (!nzchar(sample_id)) "sample ID",
      if (is.null(input$viscometer_id) || !nzchar(input$viscometer_id)) {
        "viscometer ID"
      },
      if (is.null(input$sample_type) || !nzchar(input$sample_type)) {
        "sample type"
      },
      if (is.null(input$time_1) || is.na(input$time_1) || input$time_1 <= 0) {
        "first flow time"
      },
      if (is.null(input$time_2) || is.na(input$time_2) || input$time_2 <= 0) {
        "second flow time"
      },
      if (
        is_standard &&
          (is.null(input$expected_value) || is.na(input$expected_value))
      ) {
        "expected value"
      }
    )

    if (length(missing_fields) > 0) {
      return(list(
        status = "incomplete",
        message = sprintf(
          "%s need%s to be entered before sample results can be calculated.",
          paste(missing_fields, collapse = ", "),
          if (length(missing_fields) == 1) "s" else ""
        )
      ))
    }

    # build_sample_result() emits a cli::cli_warn() when determinability
    # fails; that raw message carries ANSI escapes/bullets meant for the
    # console, not the UI. Muffle it here and instead derive a plain-text
    # summary below from the result's own fields (determinability_result,
    # determinability_difference, determinability_limit).
    computed <- tryCatch(
      withCallingHandlers(
        kinvicalc::build_sample_result(
          viscometer_id = input$viscometer_id,
          sample_type = input$sample_type,
          analysis_temperature_c = input$analysis_temperature_c,
          time_1 = input$time_1,
          time_2 = input$time_2,
          operator = user_id,
          sample_id = sample_id
        ),
        warning = function(w) invokeRestart("muffleWarning")
      ),
      error = function(e) e
    )

    if (inherits(computed, "kinvicalc_result")) {
      determinability_note <- if (
        !identical(computed$determinability_result, "pass")
      ) {
        sprintf(
          "Determinability failed. Per ASTM D445-26 11.2.3/12.4.1, repeat flow-time measurements after cleaning and drying the viscometer before reporting a final result. (Observed difference: %s mm\u00B2/s; limit: %s mm\u00B2/s.)",
          kinvicalc::format_significant(computed$determinability_difference),
          kinvicalc::format_significant(computed$determinability_limit)
        )
      } else {
        NULL
      }

      standard_check <- NULL
      if (
        is_standard &&
          !is.null(input$expected_value) &&
          !is.na(input$expected_value)
      ) {
        expected_value <- input$expected_value
        repeatability <- evaluate_standard_check(
          sample_type = computed$sample_type,
          analysis_temperature_c = computed$analysis_temperature_c,
          measured_value = computed$kinematic_viscosity_cSt,
          expected_value = expected_value,
          metric = "repeatability"
        )
        reproducibility <- evaluate_standard_check(
          sample_type = computed$sample_type,
          analysis_temperature_c = computed$analysis_temperature_c,
          measured_value = computed$kinematic_viscosity_cSt,
          expected_value = expected_value,
          metric = "reproducibility"
        )
        standard_check <- list(
          expected_value = expected_value,
          repeatability = repeatability,
          reproducibility = reproducibility
        )
      }

      list(
        status = "ok",
        result = computed,
        note = determinability_note,
        standard_check = standard_check
      )
    } else if (inherits(computed, "condition")) {
      list(status = "error", message = conditionMessage(computed))
    } else {
      list(status = "ok", result = computed, note = NULL)
    }
  })

  shiny::observe({
    attempt <- calc_attempt()
    if (identical(attempt$status, "ok")) {
      result(attempt$result)
      standard_check(attempt$standard_check %||% NULL)
    } else {
      result(NULL)
      standard_check(NULL)
    }
  })

  shiny::observeEvent(input$lock, {
    out <- result()
    if (!is.null(out) && !isTRUE(out$locked)) {
      if (identical(out$sample_type, "standard")) {
        out$standard_check <- standard_check()
      }
      locked <- kinvicalc::lock_result(out)
      result(locked)
      locked_results(c(locked_results(), list(locked)))
      # lock_result() increments viscometer use counters; refresh the
      # Viscometers tab (table + dropdown choices) so "Uses Since Clean"
      # and similar fields stay current without a separate maintenance action.
      bump_maintenance_refresh()
      lock_message(
        sprintf(
          "Locked result for sample %s.",
          if (!is.null(locked$sample_id) && nzchar(locked$sample_id)) {
            locked$sample_id
          } else {
            "(no sample ID)"
          }
        )
      )

      shiny::updateTextInput(session, "sample_id", value = "")
      shiny::updateNumericInput(session, "time_1", value = NA)
      shiny::updateNumericInput(session, "time_2", value = NA)
    }
  })

  shiny::observeEvent(
    list(input$sample_id, input$time_1, input$time_2),
    {
      lock_note <- lock_message()
      if (!is.null(lock_note) && nzchar(lock_note)) {
        sample_id_started <- nzchar(trimws(input$sample_id %||% ""))
        time_1_started <- !is.null(input$time_1) &&
          !is.na(input$time_1) &&
          input$time_1 > 0
        time_2_started <- !is.null(input$time_2) &&
          !is.na(input$time_2) &&
          input$time_2 > 0

        if (sample_id_started || time_1_started || time_2_started) {
          lock_message(NULL)
        }
      }
    },
    ignoreInit = TRUE
  )

  reset_new_viscometer_inputs <- function() {
    shiny::updateNumericInput(session, "new_viscometer_size", value = NA)
    shiny::updateTextInput(session, "new_serial_number", value = "")
    shiny::updateNumericInput(session, "new_factor_40_top", value = NA)
    shiny::updateNumericInput(session, "new_factor_40_bottom", value = NA)
    shiny::updateNumericInput(session, "new_factor_100_top", value = NA)
    shiny::updateNumericInput(session, "new_factor_100_bottom", value = NA)
    shiny::updateTextInput(session, "new_added_by", value = "")
    shiny::updateTextAreaInput(session, "new_notes", value = "")
  }

  shiny::observeEvent(input$add_viscometer, {
    shiny::req(input$new_viscometer_size)
    shiny::req(input$new_serial_number)
    shiny::req(input$new_factor_40_top)
    shiny::req(input$new_factor_40_bottom)
    shiny::req(input$new_factor_100_top)
    shiny::req(input$new_factor_100_bottom)

    viscometer_id <- tryCatch(
      kinvicalc::format_viscometer_id(
        viscometer_size = input$new_viscometer_size,
        serial_number = trimws(input$new_serial_number),
        fn = "app_server"
      ),
      error = function(e) {
        shiny::showModal(shiny::modalDialog(
          title = "Viscometer rejected",
          conditionMessage(e),
          easyClose = TRUE,
          footer = shiny::modalButton("OK")
        ))
        return(NULL)
      }
    )
    if (is.null(viscometer_id)) {
      return(invisible(NULL))
    }

    existing_ids <- kinvicalc::list_viscometers()$viscometer_id
    if (viscometer_id %in% existing_ids) {
      shiny::showModal(shiny::modalDialog(
        title = "Confirm viscometer update",
        sprintf(
          "Viscometer ID %s already exists in the registry. Update its calibration factors with the values entered above?",
          viscometer_id
        ),
        easyClose = TRUE,
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton("confirm_update_viscometer", "Update Factors")
        )
      ))
      return(invisible(NULL))
    }

    added <- tryCatch(
      kinvicalc::add_viscometer(
        tibble::tibble(
          viscometer_id = viscometer_id,
          viscometer_size = input$new_viscometer_size,
          serial_number = trimws(input$new_serial_number),
          status = "active",
          factor_40_top = input$new_factor_40_top,
          factor_40_bottom = input$new_factor_40_bottom,
          factor_100_top = input$new_factor_100_top,
          factor_100_bottom = input$new_factor_100_bottom,
          added_by = if (nzchar(input$new_added_by)) {
            input$new_added_by
          } else {
            NA_character_
          },
          notes = if (nzchar(input$new_notes)) {
            input$new_notes
          } else {
            NA_character_
          }
        )
      ),
      error = function(e) {
        shiny::showModal(shiny::modalDialog(
          title = "Viscometer rejected",
          conditionMessage(e),
          easyClose = TRUE,
          footer = shiny::modalButton("OK")
        ))
        return(NULL)
      }
    )

    if (is.null(added)) {
      return(invisible(NULL))
    }

    set_maintenance_message(
      sprintf("Added viscometer %s.", added$viscometer_id[1])
    )

    reset_new_viscometer_inputs()
  })

  shiny::observeEvent(input$confirm_update_viscometer, {
    shiny::removeModal()

    viscometer_id <- tryCatch(
      kinvicalc::format_viscometer_id(
        viscometer_size = input$new_viscometer_size,
        serial_number = trimws(input$new_serial_number),
        fn = "app_server"
      ),
      error = function(e) NULL
    )
    if (is.null(viscometer_id)) {
      return(invisible(NULL))
    }

    updated <- tryCatch(
      kinvicalc::update_viscometer_factors(
        viscometer_id,
        factor_40_top = input$new_factor_40_top,
        factor_40_bottom = input$new_factor_40_bottom,
        factor_100_top = input$new_factor_100_top,
        factor_100_bottom = input$new_factor_100_bottom,
        notes = if (nzchar(input$new_notes)) {
          input$new_notes
        } else {
          NA_character_
        },
        updated_by = if (nzchar(input$new_added_by)) {
          input$new_added_by
        } else {
          NA_character_
        }
      ),
      error = function(e) {
        shiny::showModal(shiny::modalDialog(
          title = "Viscometer update rejected",
          conditionMessage(e),
          easyClose = TRUE,
          footer = shiny::modalButton("OK")
        ))
        return(NULL)
      }
    )

    if (is.null(updated)) {
      return(invisible(NULL))
    }

    set_maintenance_message(
      sprintf("Updated viscometer %s.", updated$viscometer_id[1])
    )

    reset_new_viscometer_inputs()
  })

  shiny::observeEvent(input$mark_cleaning, {
    shiny::req(input$cleaning_viscometer_id)

    cleaned <- kinvicalc::reset_viscometer_use_count(
      input$cleaning_viscometer_id
    )
    set_maintenance_message(
      sprintf("Marked viscometer %s as cleaned.", cleaned$viscometer_id[1])
    )
  })

  shiny::observeEvent(input$archive_viscometer, {
    shiny::req(input$archive_viscometer_id)

    archived <- kinvicalc::archive_viscometer(input$archive_viscometer_id)
    set_maintenance_message(
      sprintf("Archived viscometer %s.", archived$viscometer_id[1])
    )
  })

  shiny::observeEvent(input$unarchive_viscometer, {
    shiny::req(input$unarchive_viscometer_id)

    unarchived <- kinvicalc::unarchive_viscometer(input$unarchive_viscometer_id)
    set_maintenance_message(
      sprintf("Unarchived viscometer %s.", unarchived$viscometer_id[1])
    )
  })

  output$result <- shiny::renderUI({
    out <- result()
    if (is.null(out)) {
      return(shiny::tags$em("No result yet."))
    }

    flag_note <- if (isTRUE(out$low_flow_time_flag)) {
      shiny::tags$p(
        shiny::tags$strong("FLAGGED: "),
        "flow time below 200 s -- review measurement."
      )
    } else {
      NULL
    }

    pass <- identical(out$determinability_result, "pass")
    determinability_colour <- if (pass) "#1a7f37" else "#c0392b"
    determinability_label <- if (pass) "PASS" else "FAIL"

    pass_fail_label <- function(passed) {
      colour <- if (passed) "#1a7f37" else "#c0392b"
      shiny::tags$strong(
        style = sprintf("color: %s;", colour),
        if (passed) "PASS" else "FAIL"
      )
    }

    standard_section <- NULL
    check <- standard_check()
    if (identical(out$sample_type, "standard") && !is.null(check)) {
      standard_section <- shiny::tagList(
        shiny::tags$hr(),
        shiny::tags$p(
          shiny::tags$strong("Standard reference check "),
          sprintf(
            "(expected value: %s mm\u00B2/s):",
            kinvicalc::format_significant(check$expected_value)
          )
        ),
        shiny::tags$p(
          "Repeatability -- measured: ",
          sprintf(
            "%s mm\u00B2/s",
            kinvicalc::format_significant(check$repeatability$difference)
          ),
          "; permitted: ",
          sprintf(
            "%s mm\u00B2/s",
            kinvicalc::format_significant(check$repeatability$limit)
          )
        ),
        shiny::tags$p(
          shiny::tags$strong("Repeatability: "),
          pass_fail_label(check$repeatability$passed)
        ),
        shiny::tags$p(
          "Reproducibility -- measured: ",
          sprintf(
            "%s mm\u00B2/s",
            kinvicalc::format_significant(check$reproducibility$difference)
          ),
          "; permitted: ",
          sprintf(
            "%s mm\u00B2/s",
            kinvicalc::format_significant(check$reproducibility$limit)
          )
        ),
        shiny::tags$p(
          shiny::tags$strong("Reproducibility: "),
          pass_fail_label(check$reproducibility$passed)
        )
      )
    }

    shiny::tagList(
      shiny::tags$p(
        shiny::tags$strong("Viscosity 1: "),
        sprintf(
          "%s mm\u00B2/s",
          kinvicalc::format_significant(out$kinematic_viscosity_1_cSt)
        )
      ),
      shiny::tags$p(
        shiny::tags$strong("Viscosity 2: "),
        sprintf(
          "%s mm\u00B2/s",
          kinvicalc::format_significant(out$kinematic_viscosity_2_cSt)
        )
      ),
      shiny::tags$hr(),
      shiny::tags$p(shiny::tags$strong("Determinability:")),
      shiny::tags$p(
        "Measured: ",
        sprintf(
          "%s mm\u00B2/s",
          kinvicalc::format_significant(out$determinability_difference)
        )
      ),
      shiny::tags$p(
        "Permitted: ",
        sprintf(
          "%s mm\u00B2/s",
          kinvicalc::format_significant(out$determinability_limit)
        )
      ),
      shiny::tags$p(
        shiny::tags$strong("Determinability: "),
        shiny::tags$strong(
          style = sprintf("color: %s;", determinability_colour),
          determinability_label
        )
      ),
      flag_note,
      standard_section
    )
  })

  output$calc_message <- shiny::renderUI({
    lock_note <- lock_message()
    if (!is.null(lock_note) && nzchar(lock_note)) {
      return(bslib::card(
        class = "border-success",
        shiny::tags$span(class = "text-success", lock_note)
      ))
    }

    attempt <- calc_attempt()
    if (identical(attempt$status, "incomplete")) {
      bslib::card(
        class = "border-warning",
        shiny::tags$span(class = "text-warning", attempt$message)
      )
    } else if (identical(attempt$status, "error")) {
      bslib::card(
        class = "border-danger",
        shiny::tags$span(class = "text-danger", attempt$message)
      )
    } else if (!is.null(attempt$note)) {
      bslib::card(
        class = "border-warning",
        shiny::tags$span(class = "text-warning", attempt$note)
      )
    } else {
      bslib::card(
        class = "border-success",
        shiny::tags$span(class = "text-success", "Ready to lock result.")
      )
    }
  })

  output$locked_values_table <- shiny::renderTable(
    {
      rows <- lapply(locked_results(), function(x) {
        data.frame(
          "Sample Name" = if (!is.null(x$sample_id)) {
            x$sample_id
          } else {
            NA_character_
          },
          "Sample Type" = format_sample_type_label_app(x$sample_type),
          "Analysis Temp (\u00b0 C)" = if (
            !is.null(x$analysis_temperature_c) &&
              !is.na(x$analysis_temperature_c)
          ) {
            formatC(x$analysis_temperature_c, format = "f", digits = 1)
          } else {
            NA_character_
          },
          "Viscometer ID" = x$viscometer_id,
          "t 1 (s)" = if (!is.null(x$time_1) && !is.na(x$time_1)) {
            formatC(round(x$time_1, 1), format = "f", digits = 1)
          } else {
            NA_character_
          },
          "t 2 (s)" = if (!is.null(x$time_2) && !is.na(x$time_2)) {
            formatC(round(x$time_2, 1), format = "f", digits = 1)
          } else {
            NA_character_
          },
          "Visc 1 (mm\u00B2/s)" = if (
            !is.null(x$kinematic_viscosity_1_cSt) &&
              !is.na(x$kinematic_viscosity_1_cSt)
          ) {
            kinvicalc::format_significant(
              x$kinematic_viscosity_1_cSt,
              digits = 5
            )
          } else {
            NA_character_
          },
          "Visc 2 (mm\u00B2/s)" = if (
            !is.null(x$kinematic_viscosity_2_cSt) &&
              !is.na(x$kinematic_viscosity_2_cSt)
          ) {
            kinvicalc::format_significant(
              x$kinematic_viscosity_2_cSt,
              digits = 5
            )
          } else {
            NA_character_
          },
          "Average Visc" = if (
            !is.null(x$kinematic_viscosity_cSt) &&
              !is.na(x$kinematic_viscosity_cSt)
          ) {
            kinvicalc::format_significant(x$kinematic_viscosity_cSt, digits = 5)
          } else {
            NA_character_
          },
          "QA/QC" = qa_qc_cell(x),
          "Analysis Date/Time" = if (!is.null(x$created_at)) {
            format(x$created_at, "%Y-%m-%d\n%H:%M:%S")
          } else {
            NA_character_
          },
          "Analyst" = if (!is.null(x$operator)) x$operator else NA_character_,
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      })

      if (length(rows) == 0) {
        return(data.frame(
          "Sample Name" = character(0),
          "Sample Type" = character(0),
          "Analysis Temp (\u00b0 C)" = character(0),
          "Viscometer ID" = character(0),
          "t 1 (s)" = character(0),
          "t 2 (s)" = character(0),
          "Visc 1 (mm\u00B2/s)" = character(0),
          "Visc 2 (mm\u00B2/s)" = character(0),
          "Average Visc" = character(0),
          "QA/QC" = character(0),
          "Analysis Date/Time" = character(0),
          "Analyst" = character(0),
          check.names = FALSE,
          stringsAsFactors = FALSE
        ))
      }

      do.call(rbind, rows)
    },
    striped = FALSE,
    bordered = FALSE,
    spacing = "s",
    sanitize.text.function = function(str) str
  )

  output$new_viscometer_id_preview <- shiny::renderUI({
    preview <- tryCatch(
      kinvicalc::format_viscometer_id(
        viscometer_size = input$new_viscometer_size,
        serial_number = trimws(input$new_serial_number %||% ""),
        fn = "app_server"
      ),
      error = function(e) ""
    )

    shiny::tags$p(
      shiny::tags$strong("Viscometer ID: "),
      if (nzchar(preview)) {
        shiny::tags$code(preview)
      } else {
        shiny::tags$span(
          class = "text-muted",
          "(waiting for valid size/serial)"
        )
      }
    )
  })

  new_viscometer_id_reactive <- shiny::reactive({
    tryCatch(
      kinvicalc::format_viscometer_id(
        viscometer_size = input$new_viscometer_size,
        serial_number = trimws(input$new_serial_number %||% ""),
        fn = "app_server"
      ),
      error = function(e) NA_character_
    )
  })

  new_viscometer_exists <- shiny::reactive({
    viscometer_id <- new_viscometer_id_reactive()
    if (is.na(viscometer_id) || !nzchar(viscometer_id)) {
      return(FALSE)
    }
    viscometer_id %in% kinvicalc::list_viscometers()$viscometer_id
  })

  output$add_viscometer_button <- shiny::renderUI({
    if (isTRUE(new_viscometer_exists())) {
      shiny::actionButton("add_viscometer", "Update Viscometer Factors")
    } else {
      shiny::actionButton("add_viscometer", "Add to registry")
    }
  })

  output$maintenance_status <- shiny::renderUI({
    maintenance_refresh()
    bslib::card(
      class = "border-info",
      shiny::tags$span(class = "text-info", maintenance_message())
    )
  })

  output$cleaning_table <- shiny::renderTable(
    {
      maintenance_refresh()
      viscometers <- kinvicalc::list_viscometers()

      table_cols <- c(
        "Viscometer ID",
        "Entry Date",
        "Last Clean Date",
        "Uses Since Clean",
        "Factor 40 Top",
        "Factor 40 Bottom",
        "Factor 100 Top",
        "Factor 100 Bottom",
        "Notes"
      )

      if (nrow(viscometers) == 0) {
        return(stats::setNames(
          as.data.frame(matrix(nrow = 0, ncol = length(table_cols))),
          table_cols
        ))
      }

      format_dt <- function(x) {
        x <- as.character(x)
        x[is.na(x)] <- ""
        x
      }

      data.frame(
        "Viscometer ID" = viscometers$viscometer_id,
        "Entry Date" = format_dt(viscometers$created_at %||% NA_character_),
        "Last Clean Date" = format_dt(
          viscometers$last_deep_cleaned_at %||% NA_character_
        ),
        "Uses Since Clean" = if (
          "use_count_since_cleaning" %in% names(viscometers)
        ) {
          viscometers$use_count_since_cleaning
        } else {
          rep(NA_integer_, nrow(viscometers))
        },
        "Factor 40 Top" = formatC(
          viscometers$factor_40_top,
          format = "f",
          digits = 6
        ),
        "Factor 40 Bottom" = formatC(
          viscometers$factor_40_bottom,
          format = "f",
          digits = 6
        ),
        "Factor 100 Top" = formatC(
          viscometers$factor_100_top,
          format = "f",
          digits = 6
        ),
        "Factor 100 Bottom" = formatC(
          viscometers$factor_100_bottom,
          format = "f",
          digits = 6
        ),
        "Notes" = if ("notes" %in% names(viscometers)) {
          ifelse(is.na(viscometers$notes), "", viscometers$notes)
        } else {
          rep("", nrow(viscometers))
        },
        check.names = FALSE,
        stringsAsFactors = FALSE
      )
    },
    striped = TRUE,
    bordered = TRUE,
    hover = TRUE,
    spacing = "s"
  )

  update_viscometer_inputs <- function() {
    active_choices <- viscometer_choices_app(FALSE)
    archived_choices <- viscometer_choices_app(TRUE)
    archived_only <- archived_choices[!(archived_choices %in% active_choices)]

    selected_active <- function(value, choices) {
      if (length(choices) == 0) {
        return(NULL)
      }
      if (!is.null(value) && length(value) == 1 && value %in% unname(choices)) {
        value
      } else {
        unname(choices)[1]
      }
    }

    shiny::updateSelectInput(
      session,
      "viscometer_id",
      choices = active_choices,
      selected = selected_active(input$viscometer_id, active_choices)
    )
    shiny::updateSelectInput(
      session,
      "cleaning_viscometer_id",
      choices = active_choices,
      selected = selected_active(input$cleaning_viscometer_id, active_choices)
    )
    shiny::updateSelectInput(
      session,
      "archive_viscometer_id",
      choices = active_choices,
      selected = selected_active(input$archive_viscometer_id, active_choices)
    )
    shiny::updateSelectInput(
      session,
      "unarchive_viscometer_id",
      choices = archived_only,
      selected = selected_active(input$unarchive_viscometer_id, archived_only)
    )
    shiny::updateSelectInput(
      session,
      "sample_type",
      choices = sample_type_choices_app(),
      selected = selected_active(input$sample_type, sample_type_choices_app())
    )
  }

  shiny::observe({
    maintenance_refresh()
    update_viscometer_inputs()
  })

  output$viscometer_registry <- shiny::renderPrint({
    maintenance_refresh()
    kinvicalc::list_viscometers()
  })
}

#' Run the kinvicalc Shiny application.
#'
#' @return A [shiny::shinyApp()] object.
#' @examples
#' if (interactive()) {
#'   run_app()
#' }
#' @export
run_app <- function() {
  # nocov start
  # Serve inst/shiny/www/ under "/" regardless of launch entry point
  # (run_app() directly, or inst/shiny/app.R via shiny::runApp()).
  shiny::addResourcePath(
    "www",
    system.file("shiny", "www", package = "kinvicalc")
  )

  ui <- bslib::page_fluid(
    shiny::tags$head(
      shiny::tags$link(
        rel = "icon",
        type = "image/x-icon",
        href = "www/favicon.ico"
      )
    ),
    bslib::navset_card_tab(
      bslib::nav_panel(
        "Calculation",
        bslib::card(
          bslib::card_header("Kinematic Viscosity Calculations"),
          bslib::layout_columns(
            col_widths = c(6, 6),
            shiny::div(
              shiny::textInput("user_id", "User ID", value = ""),
              shiny::textInput("sample_id", "Sample ID", value = ""),
              shiny::selectInput(
                "viscometer_id",
                "Viscometer ID",
                choices = character(0)
              ),
              shiny::selectInput(
                "sample_type",
                "Sample type",
                choices = sample_type_choices_app()
              ),
              shiny::conditionalPanel(
                condition = "input.sample_type == 'standard'",
                shiny::numericInput(
                  "expected_value",
                  "Expected Value (mm\u00B2/s)",
                  value = NA,
                  min = 0,
                  step = 0.01
                )
              ),
              shiny::numericInput(
                "analysis_temperature_c",
                "Analysis temperature (\u00b0C)",
                value = 40,
                min = -40,
                max = 150,
                step = 1
              ),
              # time_1 is resolved against the top bulb factor and time_2
              # against the bottom bulb in build_sample_result(); keep the
              # labels in that order.
              shiny::numericInput(
                "time_1",
                "Top flow time (s)",
                value = NA,
                min = 0,
                step = 0.1
              ),
              shiny::numericInput(
                "time_2",
                "Bottom flow time (s)",
                value = NA,
                min = 0,
                step = 0.1
              )
            ),
            bslib::card(
              style = "border: 2px solid black; border-radius: 12px;",
              shiny::uiOutput("result")
            )
          ),
          shiny::uiOutput("calc_message"),
          shiny::actionButton("lock", "Lock result")
        )
      ),
      bslib::nav_panel(
        "Reporting",
        shiny::tags$style(shiny::HTML(
          "
          #locked_values_table table {
            width: 100%;
            border-collapse: collapse;
          }
          #locked_values_table th,
          #locked_values_table td {
            border: 1px solid #dee2e6;
            vertical-align: middle;
            padding: 0.5rem 0.6rem;
          }
          #locked_values_table td:nth-child(11) {
            white-space: pre-line;
            text-align: center;
          }
          "
        )),
        bslib::card(
          bslib::card_header(
            "Kinematic Viscosity Results - Characterization Laboratory, NRCan"
          ),
          shiny::tableOutput("locked_values_table")
        )
      ),
      bslib::nav_panel(
        "Viscometers",
        shiny::tags$style(shiny::HTML(
          "
          #cleaning_table table {
            width: 100%;
            border-collapse: collapse;
          }
          #cleaning_table th {
            background-color: #f8f9fa;
            font-weight: 600;
          }
          #cleaning_table th,
          #cleaning_table td {
            vertical-align: middle;
            padding: 0.45rem 0.55rem;
          }
          "
        )),
        bslib::card(
          bslib::card_header("Viscometer Data & Maintenance"),
          bslib::layout_columns(
            col_widths = c(6, 6),
            shiny::div(
              shiny::tags$script(shiny::HTML(
                "
                $(document).on('keyup input', '#new_viscometer_size, #new_serial_number', function() {
                  $(this).trigger('change');
                });
                "
              )),
              shiny::numericInput(
                "new_viscometer_size",
                "Viscometer size",
                value = NA,
                min = 1,
                max = 999,
                step = 1
              ),
              shiny::textInput(
                "new_serial_number",
                "Serial number",
                value = ""
              ),
              shiny::uiOutput("new_viscometer_id_preview"),
              shiny::textInput("new_added_by", "Added by", value = ""),
              shiny::textAreaInput("new_notes", "Notes", value = "", rows = 3)
            ),
            shiny::div(
              shiny::numericInput(
                "new_factor_40_top",
                "Factor at 40 \u00b0C (top)",
                value = NA,
                min = 0
              ),
              shiny::numericInput(
                "new_factor_40_bottom",
                "Factor at 40 \u00b0C (bottom)",
                value = NA,
                min = 0
              ),
              shiny::numericInput(
                "new_factor_100_top",
                "Factor at 100 \u00b0C (top)",
                value = NA,
                min = 0
              ),
              shiny::numericInput(
                "new_factor_100_bottom",
                "Factor at 100 \u00b0C (bottom)",
                value = NA,
                min = 0
              )
            )
          ),
          shiny::uiOutput("add_viscometer_button"),
          shiny::hr(),
          shiny::selectInput(
            "cleaning_viscometer_id",
            "Viscometer ID to mark clean",
            choices = character(0)
          ),
          shiny::actionButton("mark_cleaning", "Mark cleaning"),
          shiny::selectInput(
            "archive_viscometer_id",
            "Viscometer ID to archive",
            choices = character(0)
          ),
          shiny::actionButton("archive_viscometer", "Archive viscometer"),
          shiny::selectInput(
            "unarchive_viscometer_id",
            "Viscometer ID to unarchive",
            choices = character(0)
          ),
          shiny::actionButton("unarchive_viscometer", "Unarchive viscometer"),
          shiny::hr(),
          shiny::uiOutput("maintenance_status"),
          shiny::tableOutput("cleaning_table")
        )
      )
    )
  )

  shiny::shinyApp(ui, app_server)
  # nocov end
}
