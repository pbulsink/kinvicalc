test_that("viscometer validation accepts valid IDs and rejects invalid ones", {
  expect_true(validate_viscometer("001-00001"))
  expect_false(validate_viscometer("bad-id"))
})

test_that("viscometer registry stores and retrieves records", {
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

  add_viscometer(viscometer)
  out <- get_viscometer("002-00002")

  expect_equal(out$viscometer_id[1], "002-00002")
  expect_equal(out$factor_40_top[1], 0.05)
})

test_that("remove_viscometer deletes a viscometer record", {
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

  add_viscometer(viscometer)
  expect_true(remove_viscometer("003-00003"))
  expect_error(get_viscometer("003-00003"), "No viscometer found")
})
