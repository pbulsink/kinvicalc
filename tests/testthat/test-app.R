test_that("app_server renders, calculates, and locks results", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "014-00014",
      viscometer_size = 14,
      serial_number = "00014",
      calibration_date = as.Date("2024-12-14"),
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    shiny::testServer(kinvicalc:::app_server, {
      expect_match(output$result, "No result yet.", fixed = TRUE)

      expect_warning(
        {
          session$setInputs(
            viscometer_id = "014-00014",
            sample_type = "base_oil",
            analysis_temperature_c = 40,
            time_1 = 150,
            time_2 = 151,
            calculate = 1
          )
          session$flushReact()
        },
        "determinability check failed"
      )

      expect_true(grepl("Viscosity:", output$result, fixed = TRUE))
      expect_true(grepl("FLAGGED:", output$result, fixed = TRUE))

      session$setInputs(lock = 1)
      session$flushReact()

      expect_true(grepl("Viscosity:", output$result, fixed = TRUE))
      expect_true(grepl("FLAGGED:", output$result, fixed = TRUE))

      summary <- get_viscometer_use_summary("014-00014")
      expect_equal(summary$use_count_since_cleaning[1], 1)
      expect_equal(summary$total_use_count[1], 1)
    })
  })
})
