test_that("evaluate_standard_check centres the r/R limit on the expected value, not the average", {
  with_test_reference_db({
    measured <- 5.0
    expected <- 5.02

    out_r <- kinvicalc:::evaluate_standard_check(
      "standard",
      40,
      measured_value = measured,
      expected_value = expected,
      metric = "repeatability"
    )
    out_R <- kinvicalc:::evaluate_standard_check(
      "standard",
      40,
      measured_value = measured,
      expected_value = expected,
      metric = "reproducibility"
    )

    expect_equal(out_r$difference, abs(measured - expected))
    # Limit uses the expected value alone (0.0056 * expected), not the
    # average of measured and expected.
    expect_equal(out_r$limit, 0.0056 * expected)
    expect_false(isTRUE(out_r$limit == 0.0056 * mean(c(measured, expected))))
    expect_true(out_r$passed)
    expect_equal(out_r$result, "pass")

    expect_equal(out_R$limit, 0.0122 * expected)
    expect_true(out_R$passed)
  })
})

test_that("evaluate_standard_check reports a fail when the difference exceeds the limit", {
  with_test_reference_db({
    measured <- 5.0
    expected <- 5.05 # 0.05 mm2/s off: fails repeatability, passes reproducibility

    out_r <- kinvicalc:::evaluate_standard_check(
      "standard",
      40,
      measured_value = measured,
      expected_value = expected,
      metric = "repeatability"
    )
    out_R <- kinvicalc:::evaluate_standard_check(
      "standard",
      40,
      measured_value = measured,
      expected_value = expected,
      metric = "reproducibility"
    )

    expect_equal(out_r$result, "fail")
    expect_false(out_r$passed)
    expect_equal(out_R$result, "pass")
    expect_true(out_R$passed)
  })
})

test_that("qa_qc_cell shows only determinability for non-standard sample types", {
  x <- list(
    sample_type = "base_oil",
    determinability_result = "pass",
    standard_check = NULL
  )
  cell <- kinvicalc:::qa_qc_cell(x)

  expect_match(cell, "Determ: Pass", fixed = TRUE)
  expect_match(cell, "color: #1a7f37", fixed = TRUE)
  expect_false(
    grepl("r: Pass", cell, fixed = TRUE) || grepl("r: Fail", cell, fixed = TRUE)
  )
  expect_false(
    grepl("R: Pass", cell, fixed = TRUE) || grepl("R: Fail", cell, fixed = TRUE)
  )
})

test_that("qa_qc_cell adds coloured r/R lines for standard samples", {
  x_all_pass <- list(
    sample_type = "standard",
    determinability_result = "pass",
    standard_check = list(
      repeatability = list(passed = TRUE),
      reproducibility = list(passed = TRUE)
    )
  )
  cell_pass <- kinvicalc:::qa_qc_cell(x_all_pass)
  expect_match(cell_pass, "Determ: Pass", fixed = TRUE)
  expect_match(cell_pass, "r: Pass", fixed = TRUE)
  expect_match(cell_pass, "R: Pass", fixed = TRUE)
  expect_false(grepl("#c0392b", cell_pass, fixed = TRUE))

  x_mixed <- list(
    sample_type = "standard",
    determinability_result = "fail",
    standard_check = list(
      repeatability = list(passed = FALSE),
      reproducibility = list(passed = TRUE)
    )
  )
  cell_mixed <- kinvicalc:::qa_qc_cell(x_mixed)
  expect_match(cell_mixed, "Determ: Fail", fixed = TRUE)
  expect_match(cell_mixed, "r: Fail", fixed = TRUE)
  expect_match(cell_mixed, "R: Pass", fixed = TRUE)
  # Each line coloured independently: two failing (red), one passing (green).
  expect_equal(
    lengths(regmatches(cell_mixed, gregexpr("#c0392b", cell_mixed))),
    2
  )
  expect_equal(
    lengths(regmatches(cell_mixed, gregexpr("#1a7f37", cell_mixed))),
    1
  )
})

test_that("qa_qc_cell ignores a missing standard_check even for standard samples", {
  x <- list(
    sample_type = "standard",
    determinability_result = "pass",
    standard_check = NULL
  )
  cell <- kinvicalc:::qa_qc_cell(x)
  expect_equal(cell, "<span style='color: #1a7f37;'>Determ: Pass</span>")
})

test_that("app_server shows an expected-value input requirement for the standard sample type", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 17,
      serial_number = "00017",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    shiny::testServer(kinvicalc:::app_server, {
      session$setInputs(
        user_id = "tester",
        sample_id = "std-sample-001",
        viscometer_id = "017-00017",
        sample_type = "standard",
        analysis_temperature_c = 40,
        time_1 = 205,
        time_2 = 205.5
      )
      session$flushReact()

      expect_match(
        as.character(output$calc_message$html),
        "expected value",
        fixed = TRUE
      )
    })
  })
})

test_that("app_server calculates and locks a standard sample with r/R pass shown", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 18,
      serial_number = "00018",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    shiny::testServer(kinvicalc:::app_server, {
      session$setInputs(
        user_id = "tester",
        sample_id = "std-sample-002",
        viscometer_id = "018-00018",
        sample_type = "standard",
        analysis_temperature_c = 40,
        time_1 = 205,
        time_2 = 205.5,
        expected_value = 5.13
      )
      session$flushReact()

      rendered <- as.character(output$result$html)
      expect_true(grepl("Standard reference check", rendered, fixed = TRUE))
      expect_true(grepl("Repeatability:", rendered, fixed = TRUE))
      expect_true(grepl("Reproducibility:", rendered, fixed = TRUE))
      expect_true(grepl(
        "<strong style=\"color: #1a7f37;\">PASS</strong>",
        rendered,
        fixed = TRUE
      ))

      session$setInputs(lock = 1)
      session$flushReact()

      table_html <- as.character(output$locked_values_table)
      expect_true(grepl("Determ: Pass", table_html, fixed = TRUE))
      expect_true(grepl("r: Pass", table_html, fixed = TRUE))
      expect_true(grepl("R: Pass", table_html, fixed = TRUE))
      expect_true(grepl("color: #1a7f37", table_html, fixed = TRUE))
    })
  })
})

test_that("app_server locks a standard sample with a failing repeatability check", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 19,
      serial_number = "00019",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    shiny::testServer(kinvicalc:::app_server, {
      # kinematic_viscosity ~ 5.1312; an expected value far enough away
      # fails repeatability (0.0056 * expected) but not reproducibility
      # (0.0122 * expected).
      session$setInputs(
        user_id = "tester",
        sample_id = "std-sample-003",
        viscometer_id = "019-00019",
        sample_type = "standard",
        analysis_temperature_c = 40,
        time_1 = 205,
        time_2 = 205.5,
        expected_value = 5.17
      )
      session$flushReact()
      session$setInputs(lock = 1)
      session$flushReact()

      table_html <- as.character(output$locked_values_table)
      expect_true(grepl("r: Fail", table_html, fixed = TRUE))
      expect_true(grepl("R: Pass", table_html, fixed = TRUE))
      expect_true(grepl("color: #c0392b", table_html, fixed = TRUE))
      expect_true(grepl("color: #1a7f37", table_html, fixed = TRUE))
    })
  })
})

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
