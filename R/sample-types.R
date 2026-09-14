# Sample type rules and determinability/repeatability/reproducibility checks.
#
# Precision terms and their meaning (ASTM D445-26 Section 17):
#   - determinability (d, 17.1.1/17.1.2): compares the two *determined*
#     kinematic viscosity values within one result (what this package calls
#     time_top/time_bottom -> kinematic_viscosity values).
#   - repeatability (r, 17.2.1): compares two independent *results* (each
#     already an average of two determined values) from the same operator/lab.
#   - reproducibility (R, 17.2.2): compares two independent results from
#     different operators/labs.
#
# All three are expressed as a function of the compared values' average, y or
# x (mm2/s): limit = coefficient_a * (average + offset) ^ exponent_b. A fixed
# mm2/s limit (jet fuels) is represented with exponent_b = 0, since
# coefficient_a * (average + 0) ^ 0 == coefficient_a.

precision_metrics <- c("determinability", "repeatability", "reproducibility")

#' Get a sample-type precision rule.
#'
#' If no rule is defined for `sample_type` at `analysis_temperature_c` (for
#' the given `metric`), this falls back to the `"unlisted"` rule set (ASTM
#' D445-26 12.4.1/11.2.4 fallback limits for materials/temperatures not
#' explicitly tabulated in Section 17), rather than raising an error. A rule
#' that exists but is marked unverified (`coefficient_a` is `NA`) is not
#' silently replaced by the fallback -- that still errors, since transcription
#' of that cell could not be confirmed and using the "unlisted" limit in its
#' place could mask an ASTM-defined value that differs from the fallback.
#'
#' @param sample_type Sample type label (see `.default_sample_rules()` for the
#'   supported identifiers drawn from ASTM D445-26 17.1.1, 17.1.2, 17.2.1, and
#'   17.2.2).
#' @param analysis_temperature_c Analysis temperature in C.
#' @param metric Which precision metric to retrieve: "determinability",
#'   "repeatability", or "reproducibility".
#' @return A one-row tibble for the requested rule.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' get_sample_type_rule("base_oil", 40, metric = "determinability")
#'
#' options(old_opt)
get_sample_type_rule <- function(
  sample_type,
  analysis_temperature_c = 40,
  metric = precision_metrics
) {
  metric <- match.arg(metric)
  assert_string(sample_type, "sample_type", fn = "get_sample_type_rule")
  assert_scalar_numeric(
    analysis_temperature_c,
    "analysis_temperature_c",
    fn = "get_sample_type_rule"
  )

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  fetch_rule <- function(type) {
    DBI::dbGetQuery(
      db,
      "SELECT * FROM sample_types
       WHERE sample_type = ? AND metric = ?
         AND ? >= temp_min_c AND ? <= temp_max_c
       LIMIT 1",
      params = list(
        type,
        metric,
        analysis_temperature_c,
        analysis_temperature_c
      )
    )
  }

  result <- fetch_rule(sample_type)

  if (nrow(result) == 0 && sample_type != "unlisted") {
    result <- fetch_rule("unlisted")
  }

  if (nrow(result) == 0) {
    cli::cli_abort(c(
      "{.fn get_sample_type_rule}: no {.val {metric}} rule found for sample type {.val {sample_type}} at {.val {analysis_temperature_c}} C.",
      "i" = "Add or correct a rule with {.fn add_sample_type_rule} for this sample type, metric, and temperature range."
    ))
  }

  if (is.na(result$coefficient_a[1])) {
    cli::cli_abort(c(
      "{.fn get_sample_type_rule}: the {.val {metric}} rule for {.val {sample_type}} at {.val {analysis_temperature_c}} C is marked unverified.",
      "i" = "Confirm the ASTM D445-26 Section 17 value and update the rule with {.fn add_sample_type_rule} before using this metric."
    ))
  }

  tibble::as_tibble(result)
}

#' Add or replace a sample type precision rule.
#'
#' @param rule A sample type rule record (see `validate_sample_type_rule()`
#'   for required columns).
#' @return The inserted rule.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' add_sample_type_rule(
#'   tibble::tibble(
#'     sample_type = "custom_oil",
#'     metric = "determinability",
#'     temp_min_c = 40,
#'     temp_max_c = 40,
#'     coefficient_a = 0.0040,
#'     exponent_b = 1,
#'     offset = 0,
#'     notes = "Example custom rule"
#'   )
#' )
#'
#' options(old_opt)
add_sample_type_rule <- function(rule) {
  rule <- validate_sample_type_rule(rule)

  db <- reference_db_connection()
  on.exit(DBI::dbDisconnect(db), add = TRUE)

  existing <- DBI::dbGetQuery(
    db,
    "SELECT 1 FROM sample_types WHERE sample_type = ? AND metric = ? AND temp_min_c = ? AND temp_max_c = ?",
    params = list(
      rule$sample_type[1],
      rule$metric[1],
      rule$temp_min_c[1],
      rule$temp_max_c[1]
    )
  )

  if (nrow(existing) > 0) {
    DBI::dbExecute(
      db,
      "UPDATE sample_types
       SET coefficient_a = ?, exponent_b = ?, offset = ?, notes = COALESCE(?, notes), updated_at = CURRENT_TIMESTAMP
       WHERE sample_type = ? AND metric = ? AND temp_min_c = ? AND temp_max_c = ?",
      params = list(
        rule$coefficient_a[1],
        rule$exponent_b[1],
        rule$offset[1],
        if ("notes" %in% names(rule)) rule$notes[1] else NA_character_,
        rule$sample_type[1],
        rule$metric[1],
        rule$temp_min_c[1],
        rule$temp_max_c[1]
      )
    )
  } else {
    DBI::dbExecute(
      db,
      "INSERT INTO sample_types
         (sample_type, metric, temp_min_c, temp_max_c, coefficient_a, exponent_b, offset, notes, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
      params = list(
        rule$sample_type[1],
        rule$metric[1],
        rule$temp_min_c[1],
        rule$temp_max_c[1],
        rule$coefficient_a[1],
        rule$exponent_b[1],
        rule$offset[1],
        if ("notes" %in% names(rule)) rule$notes[1] else NA_character_
      )
    )
  }

  get_sample_type_rule(rule$sample_type[1], rule$temp_min_c[1], rule$metric[1])
}

#' Calculate a precision limit from a rule and a compared value.
#'
#' @param rule A one-row precision rule tibble (see `get_sample_type_rule()`).
#' @param average_value The average of the two values being compared, mm2/s.
#' @return The numeric precision limit, mm2/s.
#' @keywords internal
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' rule <- get_sample_type_rule("base_oil", 40, metric = "determinability")
#' kinvicalc:::calculate_precision_limit(rule, average_value = 5.5)
#'
#' options(old_opt)
calculate_precision_limit <- function(rule, average_value) {
  assert_scalar_numeric(
    average_value,
    "average_value",
    fn = "calculate_precision_limit"
  )
  a <- rule$coefficient_a[1]
  b <- rule$exponent_b[1]
  offset <- if ("offset" %in% names(rule) && !is.na(rule$offset[1])) {
    rule$offset[1]
  } else {
    0
  }
  a * (average_value + offset)^b
}

#' Evaluate determinability for a sample at a given temperature.
#'
#' Per ASTM D445-26 11.2.3/14.1, determinability compares the two *determined*
#' kinematic viscosity values (not the raw flow times) that are averaged to
#' produce one reported result.
#'
#' @param sample_type Sample type label.
#' @param analysis_temperature_c Analysis temperature in C.
#' @param viscosity_1 First determined kinematic viscosity value, mm2/s.
#' @param viscosity_2 Second determined kinematic viscosity value, mm2/s.
#' @return A list containing the difference, rule limit, and pass/fail status.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' evaluate_determinability(
#'   sample_type = "base_oil",
#'   analysis_temperature_c = 40,
#'   viscosity_1 = 5.80,
#'   viscosity_2 = 5.79
#' )
#'
#' options(old_opt)
evaluate_determinability <- function(
  sample_type,
  analysis_temperature_c,
  viscosity_1,
  viscosity_2
) {
  assert_string(sample_type, "sample_type", fn = "evaluate_determinability")
  assert_scalar_numeric(
    analysis_temperature_c,
    "analysis_temperature_c",
    fn = "evaluate_determinability"
  )
  assert_scalar_numeric(
    viscosity_1,
    "viscosity_1",
    fn = "evaluate_determinability"
  )
  assert_scalar_numeric(
    viscosity_2,
    "viscosity_2",
    fn = "evaluate_determinability"
  )

  rule <- get_sample_type_rule(
    sample_type,
    analysis_temperature_c,
    metric = "determinability"
  )
  y <- mean(c(viscosity_1, viscosity_2))
  diff <- abs(viscosity_1 - viscosity_2)
  limit <- calculate_precision_limit(rule, y)
  passed <- diff <= limit

  list(
    sample_type = sample_type,
    analysis_temperature_c = analysis_temperature_c,
    average_viscosity = y,
    difference = diff,
    limit = limit,
    result = if (passed) "pass" else "fail",
    passed = passed
  )
}

#' Evaluate repeatability between two independent results.
#'
#' Per ASTM D445-26 17.2.1, repeatability compares two independent *results*
#' (each already the average of two determined values) obtained by the same
#' operator/lab/apparatus on identical material within a short time interval.
#'
#' @param sample_type Sample type label.
#' @param analysis_temperature_c Analysis temperature in C.
#' @param result_1 First reported kinematic viscosity result, mm2/s.
#' @param result_2 Second reported kinematic viscosity result, mm2/s.
#' @return A list containing the difference, rule limit, and pass/fail status.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' evaluate_repeatability(
#'   sample_type = "base_oil",
#'   analysis_temperature_c = 40,
#'   result_1 = 5.80,
#'   result_2 = 5.75
#' )
#'
#' options(old_opt)
evaluate_repeatability <- function(
  sample_type,
  analysis_temperature_c,
  result_1,
  result_2
) {
  assert_string(sample_type, "sample_type", fn = "evaluate_repeatability")
  assert_scalar_numeric(
    analysis_temperature_c,
    "analysis_temperature_c",
    fn = "evaluate_repeatability"
  )
  assert_scalar_numeric(result_1, "result_1", fn = "evaluate_repeatability")
  assert_scalar_numeric(result_2, "result_2", fn = "evaluate_repeatability")

  rule <- get_sample_type_rule(
    sample_type,
    analysis_temperature_c,
    metric = "repeatability"
  )
  x <- mean(c(result_1, result_2))
  diff <- abs(result_1 - result_2)
  limit <- calculate_precision_limit(rule, x)
  passed <- diff <= limit

  list(
    sample_type = sample_type,
    analysis_temperature_c = analysis_temperature_c,
    average_result = x,
    difference = diff,
    limit = limit,
    result = if (passed) "pass" else "fail",
    passed = passed
  )
}

#' Evaluate reproducibility between two independent results from different labs.
#'
#' Per ASTM D445-26 17.2.2, reproducibility compares two independent results
#' obtained by different operators in different laboratories.
#'
#' @param sample_type Sample type label.
#' @param analysis_temperature_c Analysis temperature in C.
#' @param result_1 First reported kinematic viscosity result, mm2/s.
#' @param result_2 Second reported kinematic viscosity result, mm2/s.
#' @return A list containing the difference, rule limit, and pass/fail status.
#' @export
#' @examples
#' old_opt <- options(kinvicalc.reference_db_path = tempfile(fileext = ".db"))
#'
#' evaluate_reproducibility(
#'   sample_type = "base_oil",
#'   analysis_temperature_c = 40,
#'   result_1 = 5.80,
#'   result_2 = 5.70
#' )
#'
#' options(old_opt)
evaluate_reproducibility <- function(
  sample_type,
  analysis_temperature_c,
  result_1,
  result_2
) {
  assert_string(sample_type, "sample_type", fn = "evaluate_reproducibility")
  assert_scalar_numeric(
    analysis_temperature_c,
    "analysis_temperature_c",
    fn = "evaluate_reproducibility"
  )
  assert_scalar_numeric(result_1, "result_1", fn = "evaluate_reproducibility")
  assert_scalar_numeric(result_2, "result_2", fn = "evaluate_reproducibility")

  rule <- get_sample_type_rule(
    sample_type,
    analysis_temperature_c,
    metric = "reproducibility"
  )
  x <- mean(c(result_1, result_2))
  diff <- abs(result_1 - result_2)
  limit <- calculate_precision_limit(rule, x)
  passed <- diff <= limit

  list(
    sample_type = sample_type,
    analysis_temperature_c = analysis_temperature_c,
    average_result = x,
    difference = diff,
    limit = limit,
    result = if (passed) "pass" else "fail",
    passed = passed
  )
}
