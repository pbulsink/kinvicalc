test_that("build_sample_result computes viscosity and determinability using base_oil rules", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 4,
      serial_number = "00004",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

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
    expect_false(result$low_flow_time_flag)
    expect_equal(result$determinability_result, "pass")
  })
})

test_that("build_sample_result flags results with a flow time below the minimum", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 5,
      serial_number = "00005",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    result <- suppressWarnings(
      build_sample_result(
        viscometer_id = "005-00005",
        sample_type = "base_oil",
        analysis_temperature_c = 40,
        time_1 = 150,
        time_2 = 151
      )
    )

    expect_true(result$low_flow_time_flag)
  })
})

test_that("build_sample_result warns when determinability fails", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 6,
      serial_number = "00006",
      status = "active",
      factor_40_top = 0.025,
      factor_40_bottom = 0.025,
      factor_100_top = 0.025,
      factor_100_bottom = 0.025
    )
    add_test_viscometer(viscometer)

    expect_warning(
      build_sample_result(
        viscometer_id = "006-00006",
        sample_type = "base_oil",
        analysis_temperature_c = 40,
        time_1 = 200,
        time_2 = 220
      ),
      "determinability check failed"
    )
  })
})
