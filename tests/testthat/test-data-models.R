test_that("build_sample_result computes viscosity and determinability using base_oil rules", {
  viscometer <- tibble::tibble(
    viscometer_id = "004-00004",
    viscometer_size = 4,
    serial_number = "00004",
    calibration_date = as.Date("2024-04-01"),
    status = "active",
    factor_40_top = 0.025,
    factor_40_bottom = 0.025,
    factor_100_top = 0.025,
    factor_100_bottom = 0.025
  )
  add_viscometer(viscometer)

  result <- build_sample_result(
    viscometer_id = "004-00004",
    sample_type = "base_oil",
    analysis_temperature_c = 40,
    time_1 = 200,
    time_2 = 200.5
  )

  expect_s3_class(result, "kinvicalc_result")
  expect_equal(result$kinematic_viscosity_1_cSt, 5)
  expect_equal(result$kinematic_viscosity_2_cSt, 5.0125)
  expect_false(result$kinetic_energy_correction_applied)
  expect_equal(result$determinability_result, "pass")
})

test_that("build_sample_result applies a kinetic energy correction below the minimum flow time", {
  viscometer <- tibble::tibble(
    viscometer_id = "005-00005",
    viscometer_size = 5,
    serial_number = "00005",
    calibration_date = as.Date("2024-05-01"),
    status = "active",
    factor_40_top = 0.025,
    factor_40_bottom = 0.025,
    factor_100_top = 0.025,
    factor_100_bottom = 0.025
  )
  add_viscometer(viscometer)

  result <- suppressWarnings(
    build_sample_result(
      viscometer_id = "005-00005",
      sample_type = "base_oil",
      analysis_temperature_c = 40,
      time_1 = 150,
      time_2 = 151,
      kinetic_energy_factor = 5
    )
  )

  expect_true(result$kinetic_energy_correction_applied)
})

test_that("build_sample_result warns when determinability fails", {
  viscometer <- tibble::tibble(
    viscometer_id = "006-00006",
    viscometer_size = 6,
    serial_number = "00006",
    calibration_date = as.Date("2024-06-01"),
    status = "active",
    factor_40_top = 0.025,
    factor_40_bottom = 0.025,
    factor_100_top = 0.025,
    factor_100_bottom = 0.025
  )
  add_viscometer(viscometer)

  expect_warning(
    build_sample_result(
      viscometer_id = "006-00006",
      sample_type = "base_oil",
      analysis_temperature_c = 40,
      time_1 = 200,
      time_2 = 220
    ),
    "Determinability check failed"
  )
})
