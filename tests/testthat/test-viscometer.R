test_that("viscometer validation accepts valid IDs and rejects invalid ones", {
  with_test_reference_db({
    expect_true(validate_viscometer("001-00001"))
    expect_false(validate_viscometer("bad-id"))
    expect_error(validate_viscometer(1), "viscometer_id")
  })
})

test_that("viscometer registry stores and retrieves records", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "002-00002",
      viscometer_size = 2,
      serial_number = "00002",
      calibration_date = as.Date("2024-02-01"),
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    out <- get_viscometer("002-00002")

    expect_equal(out$viscometer_id[1], "002-00002")
    expect_equal(out$factor_40_top[1], 0.05)
    expect_error(get_viscometer("bad-id"), "must match")
  })
})

test_that("remove_viscometer deletes a viscometer record", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "003-00003",
      viscometer_size = 3,
      serial_number = "00003",
      calibration_date = as.Date("2024-03-01"),
      status = "active",
      factor_40_top = 0.09,
      factor_40_bottom = 0.10,
      factor_100_top = 0.11,
      factor_100_bottom = 0.12
    )

    add_test_viscometer(viscometer)
    expect_true(remove_viscometer("003-00003"))
    expect_false(remove_viscometer("003-00003"))
    expect_error(get_viscometer("003-00003"), "no viscometer found")
  })
})

test_that("new viscometers initialize use counters", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "007-00007",
      viscometer_size = 7,
      serial_number = "00007",
      calibration_date = as.Date("2024-07-01"),
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    summary <- get_viscometer_use_summary("007-00007")

    expect_equal(summary$use_count_since_cleaning[1], 0)
    expect_equal(summary$total_use_count[1], 0)
    expect_true(is.na(summary$last_deep_cleaned_at[1]))
    expect_error(get_viscometer_use_summary("bad-id"), "no viscometer found")
  })
})

test_that("increment_viscometer_use increments both counters", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "008-00008",
      viscometer_size = 8,
      serial_number = "00008",
      calibration_date = as.Date("2024-08-01"),
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    increment_viscometer_use("008-00008")
    increment_viscometer_use("008-00008")

    summary <- get_viscometer_use_summary("008-00008")
    expect_equal(summary$use_count_since_cleaning[1], 2)
    expect_equal(summary$total_use_count[1], 2)
    expect_error(increment_viscometer_use("bad-id"), "no viscometer found")
  })
})

test_that("reset_viscometer_use_count resets since-cleaning only", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "009-00009",
      viscometer_size = 9,
      serial_number = "00009",
      calibration_date = as.Date("2024-09-01"),
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    increment_viscometer_use("009-00009")
    increment_viscometer_use("009-00009")
    reset <- reset_viscometer_use_count("009-00009")

    expect_equal(reset$use_count_since_cleaning[1], 0)
    expect_equal(reset$total_use_count[1], 2)
    expect_false(is.na(reset$last_deep_cleaned_at[1]))
    expect_error(reset_viscometer_use_count("bad-id"), "no viscometer found")
  })
})
