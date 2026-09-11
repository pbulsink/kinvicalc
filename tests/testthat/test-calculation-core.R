test_that("calculate_kinematic_viscosity returns expected value above minimum flow time", {
  out <- calculate_kinematic_viscosity(200, 0.025)
  expect_equal(out$viscosity, 5)
  expect_false(out$kinetic_energy_correction_applied)
})

test_that("calculate_kinematic_viscosity rejects invalid inputs", {
  expect_error(calculate_kinematic_viscosity(0, 1), "positive")
  expect_error(
    calculate_kinematic_viscosity(1, NA_real_),
    "single numeric value"
  )
})

test_that("calculate_kinematic_viscosity requires a kinetic energy factor below minimum flow time", {
  expect_error(
    calculate_kinematic_viscosity(150, 0.025),
    "kinetic energy correction is required"
  )
})

test_that("calculate_kinematic_viscosity applies the kinetic energy correction below minimum flow time", {
  out <- calculate_kinematic_viscosity(150, 0.025, kinetic_energy_factor = 5)
  expected <- 150 * 0.025 - 5 / 150^2
  expect_equal(out$viscosity, expected)
  expect_true(out$kinetic_energy_correction_applied)
})

test_that("calculate_kinematic_viscosity rejects an excessive kinetic energy correction", {
  expect_error(
    calculate_kinematic_viscosity(50, 0.0005, kinetic_energy_factor = 50),
    "exceeds the 3.0"
  )
})

test_that("resolve_calibration_factor interpolates between standard temperatures", {
  viscometer <- tibble::tibble(
    viscometer_id = "001-00001",
    viscometer_size = 1,
    serial_number = "00001",
    calibration_date = as.Date("2024-01-01"),
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
