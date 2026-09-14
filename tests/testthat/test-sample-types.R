test_that("determinability checks resolve rules and pass/fail logic using percentage-of-result limits", {
  # Base oil at 40 C: determinability limit is 0.0037 * y (D445-26 17.1.1)
  y <- mean(c(100, 100.3))
  expect_lt(abs(100 - 100.3), 0.0037 * y)

  out_pass <- evaluate_determinability("base_oil", 40, 100, 100.3)
  expect_equal(out_pass$result, "pass")
  expect_equal(out_pass$limit, 0.0037 * mean(c(100, 100.3)))

  out_fail <- evaluate_determinability("base_oil", 40, 100, 101.5)
  expect_equal(out_fail$result, "fail")
})

test_that("determinability limit scales with the magnitude of the result (percentage form)", {
  low <- evaluate_determinability("base_oil", 40, 10, 10.03)
  high <- evaluate_determinability("base_oil", 40, 1000, 1003)

  expect_equal(low$limit, 0.0037 * mean(c(10, 10.03)))
  expect_equal(high$limit, 0.0037 * mean(c(1000, 1003)))
  expect_gt(high$limit, low$limit)
})

test_that("determinability supports the offset formula form (gas oils)", {
  # Gas oils at 40 C: 0.0013 * (y + 1) (D445-26 17.1.1)
  y <- mean(c(5, 5.01))
  out <- evaluate_determinability("gas_oil", 40, 5, 5.01)
  expect_equal(out$limit, 0.0013 * (y + 1))
})

test_that("determinability supports the power-law formula form (additives)", {
  # Additives at 100 C: 0.00106 * y^1.1 (D445-26 17.1.1)
  y <- mean(c(200, 200.5))
  out <- evaluate_determinability("additive", 100, 200, 200.5)
  expect_equal(out$limit, 0.00106 * y^1.1)
})

test_that("determinability supports a fixed absolute limit (jet fuels)", {
  # Jet fuels at -20 C: fixed 0.01617 mm2/s, independent of magnitude
  out <- evaluate_determinability("jet_fuel", -20, 3, 3.01)
  expect_equal(out$limit, 0.01617)
})

test_that("unlisted materials fall back to the standard's estimate", {
  out <- evaluate_determinability("unlisted", 40, 50, 50.4)
  expect_equal(out$limit, 0.010 * mean(c(50, 50.4)))
})

test_that("get_sample_type_rule falls back to the unlisted rule instead of erroring", {
  # "unknown_material" has no rows in the sample_types table at all, but
  # determinability has "unlisted" rows covering 15-100 C (D445-26 12.4.1).
  out <- get_sample_type_rule(
    "unknown_material",
    40,
    metric = "determinability"
  )
  expect_equal(out$sample_type[1], "unlisted")
  expect_equal(out$coefficient_a[1], 0.010)

  det <- evaluate_determinability("unknown_material", 40, 50, 50.4)
  expect_equal(det$limit, 0.010 * mean(c(50, 50.4)))
})

test_that("get_sample_type_rule fallback still respects unverified unlisted cells", {
  # If even the "unlisted" fallback itself is unverified for a metric/temp
  # (as seeded directly, bypassing add_sample_type_rule's validation which
  # forbids NA coefficients), still error loudly rather than silently
  # guessing.
  db <- kinvicalc:::reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  DBI::dbExecute(
    db,
    "INSERT INTO sample_types
       (sample_type, metric, temp_min_c, temp_max_c, coefficient_a, exponent_b, offset, notes, created_at, updated_at)
     VALUES ('unlisted', 'repeatability', 200, 200, NULL, 1, 0, 'intentionally unverified fallback for this test', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
  )

  expect_error(
    get_sample_type_rule(
      "totally_unknown_material",
      200,
      metric = "repeatability"
    ),
    "marked unverified"
  )
})

test_that("repeatability and reproducibility use their own D445 tables", {
  rep_out <- evaluate_repeatability("base_oil", 40, 100, 100.9)
  repro_out <- evaluate_reproducibility("base_oil", 40, 100, 101.2)

  expect_equal(rep_out$limit, 0.0101 * mean(c(100, 100.9)))
  expect_equal(repro_out$limit, 0.0136 * mean(c(100, 101.2)))
})

test_that("unverified precision cells raise a clear error rather than a silent guess", {
  expect_error(
    evaluate_repeatability("kerosine_diesel_biodiesel", 40, 3, 3.02),
    "no \"repeatability\" rule found"
  )
})

test_that("pretty sample type labels are title-cased", {
  expect_equal(kinvicalc:::format_sample_type_label("jet_fuel"), "Jet Fuel")
  expect_equal(
    kinvicalc:::format_sample_type_label("used_inservice_formulated_oil"),
    "Used Inservice Formulated Oil"
  )
})

test_that("standard sample type has determinability/repeatability/reproducibility rules", {
  with_test_reference_db({
    rule_d <- get_sample_type_rule("standard", 40, metric = "determinability")
    rule_r <- get_sample_type_rule("standard", 40, metric = "repeatability")
    rule_R <- get_sample_type_rule("standard", 40, metric = "reproducibility")

    expect_equal(rule_d$coefficient_a[1], 0.0037)
    expect_equal(rule_r$coefficient_a[1], 0.0056)
    expect_equal(rule_R$coefficient_a[1], 0.0122)

    # -Inf/Inf temperature bounds: the standard rule applies at any
    # analysis temperature, unlike ASTM-tabulated sample types.
    expect_equal(
      get_sample_type_rule(
        "standard",
        -40,
        metric = "determinability"
      )$coefficient_a[1],
      0.0037
    )
    expect_equal(
      get_sample_type_rule(
        "standard",
        150,
        metric = "reproducibility"
      )$coefficient_a[1],
      0.0122
    )
  })
})

test_that("evaluate_determinability works for the standard sample type", {
  with_test_reference_db({
    out_pass <- evaluate_determinability("standard", 40, 5.0, 5.01)
    expect_equal(out_pass$result, "pass")
    expect_equal(out_pass$limit, 0.0037 * mean(c(5.0, 5.01)))

    out_fail <- evaluate_determinability("standard", 40, 5.0, 5.5)
    expect_equal(out_fail$result, "fail")
  })
})

test_that("add_sample_type_rule stores and retrieves a custom rule", {
  rule <- tibble::tibble(
    sample_type = "custom_oil",
    metric = "determinability",
    temp_min_c = 40,
    temp_max_c = 40,
    coefficient_a = 0.02,
    exponent_b = 1,
    offset = 0,
    notes = "test rule"
  )

  add_sample_type_rule(rule)

  out <- get_sample_type_rule("custom_oil", 40, metric = "determinability")
  expect_equal(out$coefficient_a[1], 0.02)

  det <- evaluate_determinability("custom_oil", 40, 10, 10.1)
  expect_equal(det$limit, 0.02 * mean(c(10, 10.1)))
})
