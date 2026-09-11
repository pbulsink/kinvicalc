#' Run the kinvicalc Shiny application.
#'
#' @param sample_type A sample type code.
#' @export
format_sample_type_label_app <- function(sample_type) {
  tools::toTitleCase(gsub("_", " ", sample_type, fixed = TRUE))
}

sample_type_choices_app <- function() {
  stats::setNames(
    c(
      "kerosine_diesel_biodiesel",
      "jet_fuel",
      "unlisted",
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

`%||%` <- function(x, y) if (is.null(x)) y else x

app_server <- function(input, output, session) {
  result <- shiny::reactiveVal(NULL)
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
      list(status = "ok", result = computed, note = determinability_note)
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
    } else {
      result(NULL)
    }
  })

  shiny::observeEvent(input$lock, {
    out <- result()
    if (!is.null(out) && !isTRUE(out$locked)) {
      locked <- kinvicalc::lock_result(out)
      result(locked)
      locked_results(c(locked_results(), list(locked)))
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

  shiny::observeEvent(input$add_viscometer, {
    shiny::req(input$new_viscometer_size)
    shiny::req(input$new_serial_number)
    shiny::req(input$new_factor_40_top)
    shiny::req(input$new_factor_40_bottom)
    shiny::req(input$new_factor_100_top)
    shiny::req(input$new_factor_100_bottom)

    viscometer_id <- tryCatch(
      format_viscometer_id(
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
        title = "Viscometer rejected",
        sprintf(
          "Viscometer ID %s already exists in the registry. Entry was not saved.",
          viscometer_id
        ),
        easyClose = TRUE,
        footer = shiny::modalButton("OK")
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
      flag_note
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
          "Analysis Temp (deg C)" = if (
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
          "Determinability" = if (identical(x$determinability_result, "pass")) {
            "Pass"
          } else {
            "False"
          },
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
          "Analysis Temp (deg C)" = character(0),
          "Viscometer ID" = character(0),
          "t 1 (s)" = character(0),
          "t 2 (s)" = character(0),
          "Visc 1 (mm\u00B2/s)" = character(0),
          "Visc 2 (mm\u00B2/s)" = character(0),
          "Average Visc" = character(0),
          "Determinability" = character(0),
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
    spacing = "s"
  )

  output$new_viscometer_id_preview <- shiny::renderUI({
    preview <- tryCatch(
      format_viscometer_id(
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

run_app <- function() {
  # nocov start
  ui <- bslib::page_fluid(
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
              shiny::numericInput(
                "analysis_temperature_c",
                "Analysis temperature (\u00b0C)",
                value = 40,
                min = -40,
                max = 150,
                step = 1
              ),
              shiny::numericInput(
                "time_1",
                "First flow time (s)",
                value = NA,
                min = 0,
                step = 0.1
              ),
              shiny::numericInput(
                "time_2",
                "Second flow time (s)",
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
              shiny::numericInput(
                "new_viscometer_size",
                "Viscometer size",
                value = 10,
                min = 1,
                max = 999,
                step = 1
              ),
              shiny::textInput(
                "new_serial_number",
                "Serial number",
                value = "00010"
              ),
              shiny::uiOutput("new_viscometer_id_preview"),
              shiny::textInput("new_added_by", "Added by", value = ""),
              shiny::textAreaInput("new_notes", "Notes", value = "", rows = 3)
            ),
            shiny::div(
              shiny::numericInput(
                "new_factor_40_top",
                "Factor at 40 \u00b0C (top)",
                value = 0.025,
                min = 0
              ),
              shiny::numericInput(
                "new_factor_40_bottom",
                "Factor at 40 \u00b0C (bottom)",
                value = 0.025,
                min = 0
              ),
              shiny::numericInput(
                "new_factor_100_top",
                "Factor at 100 \u00b0C (top)",
                value = 0.025,
                min = 0
              ),
              shiny::numericInput(
                "new_factor_100_bottom",
                "Factor at 100 \u00b0C (bottom)",
                value = 0.025,
                min = 0
              )
            )
          ),
          shiny::actionButton("add_viscometer", "Add to registry"),
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

app <- run_app()
