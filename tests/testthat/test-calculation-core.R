test_that("calculate_kinematic_viscosity returns expected value above minimum flow time", {
  out <- calculate_kinematic_viscosity(200, 0.025)
  expect_equal(out$viscosity, 5)
  expect_false(out$low_flow_time_flag)
})

test_that("calculate_kinematic_viscosity rejects invalid inputs", {
  expect_error(calculate_kinematic_viscosity(0, 1), "positive")
  expect_error(
    calculate_kinematic_viscosity(1, NA_real_),
    "single numeric value"
  )
})

test_that("calculate_kinematic_viscosity flags flow times below the minimum", {
  out <- calculate_kinematic_viscosity(150, 0.025)
  expect_equal(out$viscosity, round(150 * 0.025, 4))
  expect_true(out$low_flow_time_flag)
})

test_that("calculate_kinematic_viscosity rounds using round-half-to-even", {
  # 0.00005 rounded to 4 decimal places should round to the nearest even digit
  out <- calculate_kinematic_viscosity(2, 0.000125)
  expect_equal(out$viscosity, round(2 * 0.000125, 4))
})

test_that("resolve_calibration_factor interpolates between standard temperatures", {
  viscometer <- tibble::tibble(
    viscometer_size = 1,
    serial_number = "00001",
    status = "active",
    factor_40_top = 0.02,
    factor_40_bottom = 0.03,
    factor_100_top = 0.04,
    factor_100_bottom = 0.05
  )

  expect_equal(resolve_calibration_factor(viscometer, 70, "top"), 0.03)
  expect_equal(resolve_calibration_factor(viscometer, 40, "bottom"), 0.03)
  expect_equal(resolve_calibration_factor(viscometer, 100, "top"), 0.04)
})
