test_that("app_server renders, calculates, and locks results ", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 14,
      serial_number = "00014",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    shiny::testServer(kinvicalc:::app_server, {
      expect_true(grepl(
        "No result yet",
        as.character(output$result$html),
        fixed = TRUE
      ))

      session$setInputs(
        user_id = "tester",
        sample_id = "sample-001",
        viscometer_id = "014-00014",
        sample_type = "base_oil",
        analysis_temperature_c = 40,
        time_1 = 150,
        time_2 = 151
      )
      session$flushReact()

      rendered <- as.character(output$result$html)
      expect_true(grepl("Viscosity 1", rendered, fixed = TRUE))
      expect_true(grepl("FLAGGED", rendered, fixed = TRUE))
      expect_true(grepl(
        "Determinability failed",
        as.character(output$calc_message$html),
        fixed = TRUE
      ))

      session$setInputs(lock = 1)
      session$flushReact()

      rendered <- as.character(output$result$html)
      expect_true(grepl("Viscosity 1", rendered, fixed = TRUE))
      expect_true(grepl("FLAGGED", rendered, fixed = TRUE))

      summary <- get_viscometer_use_summary("014-00014")
      expect_equal(summary$use_count_since_cleaning[1], 1)
      expect_equal(summary$total_use_count[1], 1)
    })
  })
})

test_that("app_server supports viscometer maintenance actions ", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 15,
      serial_number = "00015",
      status = "active",
      factor_40_top = 0.03,
      factor_40_bottom = 0.03,
      factor_100_top = 0.03,
      factor_100_bottom = 0.03
    )
    add_test_viscometer(viscometer)

    shiny::testServer(kinvicalc:::app_server, {
      session$setInputs(
        new_viscometer_size = 16,
        new_serial_number = "00016"
      )
      session$flushReact()
      expect_match(
        as.character(output$new_viscometer_id_preview$html),
        "016-00016",
        fixed = TRUE
      )

      session$setInputs(
        new_factor_40_top = 0.04,
        new_factor_40_bottom = 0.04,
        new_factor_100_top = 0.05,
        new_factor_100_bottom = 0.05,
        new_added_by = "tester",
        new_notes = "maintained",
        add_viscometer = 1
      )
      session$flushReact()

      expect_match(
        as.character(output$maintenance_status$html),
        "Added viscometer 016-00016.",
        fixed = TRUE
      )
      expect_equal(get_viscometer("016-00016")$added_by[1], "tester")
      expect_equal(get_viscometer("016-00016")$notes[1], "maintained")

      increment_viscometer_use("016-00016")
      session$setInputs(cleaning_viscometer_id = "016-00016", mark_cleaning = 1)
      session$flushReact()

      expect_match(
        as.character(output$maintenance_status$html),
        "Marked viscometer 016-00016 as cleaned.",
        fixed = TRUE
      )
      expect_equal(
        get_viscometer_use_summary("016-00016")$use_count_since_cleaning[1],
        0
      )

      session$setInputs(
        archive_viscometer_id = "016-00016",
        archive_viscometer = 1
      )
      session$flushReact()
      expect_match(
        as.character(output$maintenance_status$html),
        "Archived viscometer 016-00016.",
        fixed = TRUE
      )
      expect_false(is.na(get_viscometer("016-00016")$archived_at[1]))

      session$setInputs(
        unarchive_viscometer_id = "016-00016",
        unarchive_viscometer = 1
      )
      session$flushReact()
      expect_match(
        as.character(output$maintenance_status$html),
        "Unarchived viscometer 016-00016.",
        fixed = TRUE
      )
      expect_true(is.na(get_viscometer("016-00016")$archived_at[1]))
      expect_true(nrow(list_viscometers()) >= 1)
    })
  })
})
