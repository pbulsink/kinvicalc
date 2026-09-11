test_that("save_reference_data and load_reference_data round-trip viscometers and sample rules", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_id = "011-00011",
      viscometer_size = 11,
      serial_number = "00011",
      calibration_date = as.Date("2024-11-01"),
      status = "active",
      factor_40_top = 0.11,
      factor_40_bottom = 0.12,
      factor_100_top = 0.13,
      factor_100_bottom = 0.14,
      use_count_since_cleaning = 3L,
      total_use_count = 5L,
      last_deep_cleaned_at = "2024-11-02 10:00:00",
      archived_at = NA_character_
    )

    sample_rule <- tibble::tibble(
      sample_type = "round_trip_oil",
      metric = "determinability",
      temp_min_c = 40,
      temp_max_c = 40,
      coefficient_a = 0.02,
      exponent_b = 1,
      offset = 0,
      notes = "round trip rule",
      created_at = "2024-11-01 00:00:00",
      updated_at = "2024-11-01 00:00:00"
    )

    save_reference_data(viscometers = viscometer, sample_types = sample_rule)
    out <- load_reference_data()

    expect_equal(nrow(out$viscometers), 1)
    expect_equal(out$viscometers$viscometer_id[1], "011-00011")
    expect_equal(out$viscometers$total_use_count[1], 5L)
    expect_true(is.na(out$viscometers$archived_at[1]))
    expect_equal(nrow(out$sample_types), 1)
    expect_equal(out$sample_types$sample_type[1], "round_trip_oil")
  })
})

test_that("save_reference_data rejects malformed reference tables", {
  bad_viscometer <- tibble::tibble(viscometer_id = "bad")
  bad_rule <- tibble::tibble(sample_type = "bad")

  expect_error(
    save_reference_data(viscometers = bad_viscometer),
    "missing required columns"
  )
  expect_error(
    save_reference_data(sample_types = bad_rule),
    "missing required columns"
  )
})

test_that("load_reference_data seeds default precision rules when missing", {
  save_reference_data(
    viscometers = tibble::tibble(),
    sample_types = tibble::tibble()
  )
  out <- load_reference_data()

  expect_gt(nrow(out$sample_types), 0)
  expect_equal(nrow(out$viscometers), 0)
})
