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
      "base_oil",
      "formulated_oil",
      "petroleum_wax",
      "residual_fuel_oil",
      "additive",
      "gas_oil",
      "jet_fuel",
      "kerosine_diesel_biodiesel",
      "used_inservice_formulated_oil",
      "unlisted"
    ),
    c(
      "Base Oil",
      "Formulated Oil",
      "Petroleum Wax",
      "Residual Fuel Oil",
      "Additive",
      "Gas Oil",
      "Jet Fuel",
      "Kerosine Diesel Biodiesel",
      "Used Inservice Formulated Oil",
      "Unlisted"
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

app_server <- function(input, output, session) {
  result <- shiny::reactiveVal(NULL)
  maintenance_message <- shiny::reactiveVal("No maintenance action yet.")
  maintenance_refresh <- shiny::reactiveVal(0L)

  bump_maintenance_refresh <- function() {
    maintenance_refresh(maintenance_refresh() + 1L)
  }

  set_maintenance_message <- function(message) {
    maintenance_message(message)
    bump_maintenance_refresh()
  }

  shiny::observeEvent(input$calculate, {
    shiny::req(input$viscometer_id)
    shiny::req(input$sample_type)

    result(
      kinvicalc::build_sample_result(
        viscometer_id = input$viscometer_id,
        sample_type = input$sample_type,
        analysis_temperature_c = input$analysis_temperature_c,
        time_1 = input$time_1,
        time_2 = input$time_2
      )
    )
  })

  shiny::observeEvent(input$lock, {
    out <- result()
    if (!is.null(out)) {
      result(kinvicalc::lock_result(out))
    }
  })

  shiny::observeEvent(input$add_viscometer, {
    shiny::req(input$new_viscometer_id)
    shiny::req(input$new_viscometer_size)
    shiny::req(input$new_serial_number)
    shiny::req(input$new_calibration_date)
    shiny::req(input$new_factor_40_top)
    shiny::req(input$new_factor_40_bottom)
    shiny::req(input$new_factor_100_top)
    shiny::req(input$new_factor_100_bottom)

    added <- kinvicalc::add_viscometer(
      tibble::tibble(
        viscometer_id = input$new_viscometer_id,
        viscometer_size = input$new_viscometer_size,
        serial_number = input$new_serial_number,
        calibration_date = input$new_calibration_date,
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
        notes = if (nzchar(input$new_notes)) input$new_notes else NA_character_
      )
    )

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

  output$result <- shiny::renderPrint({
    out <- result()
    if (is.null(out)) {
      "No result yet."
    } else {
      flag_note <- if (isTRUE(out$low_flow_time_flag)) {
        "\nFLAGGED: flow time below 200 s -- review measurement."
      } else {
        ""
      }
      sprintf(
        "Viscosity: %s mm2/s\nDeterminability: %s (%s of %s)%s",
        kinvicalc::format_significant(out$kinematic_viscosity_cSt),
        out$determinability_result,
        kinvicalc::format_significant(out$determinability_difference),
        kinvicalc::format_significant(out$determinability_limit),
        flag_note
      )
    }
  })

  output$maintenance_status <- shiny::renderPrint({
    maintenance_refresh()
    maintenance_message()
  })

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
          bslib::card_header("kinvicalc"),
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
            value = 200,
            min = 0,
            step = 0.1
          ),
          shiny::numericInput(
            "time_2",
            "Second flow time (s)",
            value = 210,
            min = 0,
            step = 0.1
          ),
          shiny::actionButton("calculate", "Calculate"),
          shiny::verbatimTextOutput("result"),
          shiny::actionButton("lock", "Lock result")
        )
      ),
      bslib::nav_panel(
        "Maintenance",
        bslib::card(
          bslib::card_header("Viscometer maintenance"),
          shiny::textInput(
            "new_viscometer_id",
            "Viscometer ID",
            value = "010-00010"
          ),
          shiny::numericInput(
            "new_viscometer_size",
            "Viscometer size",
            value = 10,
            min = 1,
            step = 1
          ),
          shiny::textInput(
            "new_serial_number",
            "Serial number",
            value = "00010"
          ),
          shiny::dateInput(
            "new_calibration_date",
            "Calibration date",
            value = Sys.Date()
          ),
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
          ),
          shiny::textInput("new_added_by", "Added by", value = ""),
          shiny::textAreaInput("new_notes", "Notes", value = "", rows = 3),
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
          shiny::verbatimTextOutput("maintenance_status"),
          shiny::verbatimTextOutput("viscometer_registry")
        )
      )
    )
  )

  shiny::shinyApp(ui, app_server)
  # nocov end
}

app <- run_app()
