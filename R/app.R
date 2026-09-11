#' Run the kinvicalc Shiny application.
#'
#' @export
app_server <- function(input, output, session) {
  result <- shiny::reactiveVal(NULL)

  shiny::observeEvent(input$calculate, {
    shiny::req(input$viscometer_id)
    shiny::req(input$sample_type)

    result(
      build_sample_result(
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
      result(lock_result(out))
    }
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
        format_significant(out$kinematic_viscosity_cSt),
        out$determinability_result,
        format_significant(out$determinability_difference),
        format_significant(out$determinability_limit),
        flag_note
      )
    }
  })
}

run_app <- function() {
  # nocov start
  ui <- bslib::page_fluid(
    bslib::card(
      bslib::card_header("kinvicalc"),
      shiny::textInput("viscometer_id", "Viscometer ID", value = "001-00001"),
      shiny::selectInput(
        "sample_type",
        "Sample type",
        choices = c(
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
        selected = "base_oil"
      ),
      shiny::numericInput(
        "analysis_temperature_c",
        "Analysis temperature (C)",
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
  )

  shiny::shinyApp(ui, app_server)
} # nocov end
