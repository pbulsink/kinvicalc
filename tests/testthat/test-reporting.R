test_that("lock_result marks result locked and increments viscometer use", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 10,
      serial_number = "00010",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    result <- build_sample_result(
      viscometer_id = "010-00010",
      sample_type = "base_oil",
      analysis_temperature_c = 40,
      time_1 = 200,
      time_2 = 200.5
    )

    locked <- lock_result(result)
    summary <- get_viscometer_use_summary("010-00010")

    expect_true(isTRUE(locked$locked))
    expect_false(is.null(locked$locked_at))
    expect_equal(summary$use_count_since_cleaning[1], 1)
    expect_equal(summary$total_use_count[1], 1)
  })
})

test_that("render_primary_report and render_high_density_report validate inputs", {
  expect_error(render_primary_report(NULL), "must be created")
  expect_error(render_primary_report(list()), "must be created")
  expect_error(
    render_high_density_report(NULL),
    "must contain at least one result object"
  )
  expect_error(
    render_high_density_report(list()),
    "must contain at least one result object"
  )
  expect_error(render_high_density_report(list(list())), "must be objects from")
})

test_that("render_primary_report and render_high_density_report write text outputs", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 12,
      serial_number = "00012",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    result <- suppressWarnings(
      build_sample_result(
        viscometer_id = "012-00012",
        sample_type = "base_oil",
        analysis_temperature_c = 40,
        time_1 = 150,
        time_2 = 151
      )
    )

    primary_path <- tempfile(fileext = ".html")
    high_density_path <- tempfile(fileext = ".txt")

    render_primary_report(result, output_path = primary_path, digits = 4)
    render_high_density_report(
      list(result),
      output_path = high_density_path,
      digits = 4
    )

    primary <- readLines(primary_path, warn = FALSE)
    high_density <- readLines(high_density_path, warn = FALSE)

    expect_true(any(grepl("Flagged:", primary, fixed = TRUE)))
    expect_true(any(grepl(
      "FLAG: flow time < 200 s",
      high_density,
      fixed = TRUE
    )))
  })
})

test_that("session_results_table summarizes result lists", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 13,
      serial_number = "00013",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    result <- build_sample_result(
      viscometer_id = "013-00013",
      sample_type = "base_oil",
      analysis_temperature_c = 40,
      time_1 = 200,
      time_2 = 200.5
    )

    tab <- session_results_table(list(result))

    expect_equal(nrow(tab), 1)
    expect_equal(tab$viscometer_id[1], "013-00013")
    expect_false(tab$locked[1])
    expect_false(tab$low_flow_time_flag[1])
  })
})
