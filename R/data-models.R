# Shared validations and result assembly.

viscometer_required_fields <- c(
  "viscometer_id",
  "viscometer_size",
  "serial_number",
  "calibration_date",
  "status",
  "factor_40_top",
  "factor_40_bottom",
  "factor_100_top",
  "factor_100_bottom"
)

sample_rule_required_fields <- c(
  "sample_type",
  "metric",
  "temp_min_c",
  "temp_max_c",
  "coefficient_a",
  "exponent_b",
  "offset"
)

#' Validate a viscometer record.
#'
#' Checks that a viscometer record contains all required columns and valid values.
#'
#' @param viscometer A data frame-like object representing one viscometer.
#' @return The validated viscometer tibble.
#' @export
validate_viscometer_record <- function(viscometer) {
  if (is.null(viscometer) || !is.data.frame(viscometer)) {
    cli::cli_abort(c(
      "{.fn validate_viscometer_record}: {.arg viscometer} must be a data frame or tibble.",
      "i" = "Pass a one-row viscometer record with all required fields."
    ))
  }

  missing_cols <- setdiff(viscometer_required_fields, names(viscometer))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "{.fn validate_viscometer_record}: viscometer record is missing required columns: {paste(missing_cols, collapse = ', ')}.",
      "i" = "Add the missing columns before saving or validating the record."
    ))
  }

  assert_string(
    viscometer$viscometer_id[1],
    "viscometer_id",
    fn = "validate_viscometer_record"
  )
  if (!is_valid_viscometer_id(viscometer$viscometer_id[1])) {
    cli::cli_abort(c(
      "{.fn validate_viscometer_record}: {.arg viscometer_id} must match {.val ###-#####}.",
      "i" = "Viscometers must be named {.val ###-#####} corresponding to size-serial number."
    ))
  }

  assert_scalar_numeric(
    viscometer$viscometer_size[1],
    "viscometer_size",
    fn = "validate_viscometer_record"
  )
  assert_string(
    viscometer$serial_number[1],
    "serial_number",
    fn = "validate_viscometer_record"
  )
  assert_date(
    viscometer$calibration_date[1],
    "calibration_date",
    fn = "validate_viscometer_record"
  )
  assert_string(
    viscometer$status[1],
    "status",
    fn = "validate_viscometer_record"
  )

  required_factors <- c(
    "factor_40_top",
    "factor_40_bottom",
    "factor_100_top",
    "factor_100_bottom"
  )

  for (field in required_factors) {
    if (is.na(viscometer[[field]][1]) || !is.numeric(viscometer[[field]][1])) {
      cli::cli_abort(c(
        "{.fn validate_viscometer_record}: viscometer record must include a numeric value for {.arg {field}}.",
        "i" = "Enter calibrated numeric factors for all four fields: factor_40_top, factor_40_bottom, factor_100_top, and factor_100_bottom."
      ))
    }
  }

  tibble::as_tibble(viscometer)
}

#' Validate a sample-type precision rule.
#'
#' @param rule A data frame-like record containing precision settings (see
#'   `precision_metrics` for supported `metric` values).
#' @return The validated rule tibble.
#' @export
validate_sample_type_rule <- function(rule) {
  if (is.null(rule) || !is.data.frame(rule)) {
    cli::cli_abort(c(
      "{.fn validate_sample_type_rule}: {.arg rule} must be a data frame or tibble.",
      "i" = "Pass one rule record containing the required precision columns."
    ))
  }

  missing_cols <- setdiff(sample_rule_required_fields, names(rule))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "{.fn validate_sample_type_rule}: sample type rule is missing required columns: {paste(missing_cols, collapse = ', ')}.",
      "i" = "Add the missing columns before calling {.fn add_sample_type_rule}."
    ))
  }

  assert_string(
    rule$sample_type[1],
    "sample_type",
    fn = "validate_sample_type_rule"
  )
  if (!rule$metric[1] %in% precision_metrics) {
    cli::cli_abort(c(
      "{.fn validate_sample_type_rule}: {.arg metric} must be one of {paste(precision_metrics, collapse = ', ')}.",
      "i" = "Use {.val determinability}, {.val repeatability}, or {.val reproducibility}."
    ))
  }
  assert_scalar_numeric(
    rule$temp_min_c[1],
    "temp_min_c",
    fn = "validate_sample_type_rule"
  )
  assert_scalar_numeric(
    rule$temp_max_c[1],
    "temp_max_c",
    fn = "validate_sample_type_rule"
  )
  if (rule$temp_min_c[1] > rule$temp_max_c[1]) {
    cli::cli_abort(c(
      "{.fn validate_sample_type_rule}: {.arg temp_min_c} must be less than or equal to {.arg temp_max_c}.",
      "i" = "Swap the bounds or correct the target temperature range for this rule."
    ))
  }
  assert_scalar_numeric(
    rule$coefficient_a[1],
    "coefficient_a",
    fn = "validate_sample_type_rule"
  )
  assert_scalar_numeric(
    rule$exponent_b[1],
    "exponent_b",
    fn = "validate_sample_type_rule"
  )
  if ("offset" %in% names(rule) && !is.na(rule$offset[1])) {
    assert_scalar_numeric(
      rule$offset[1],
      "offset",
      fn = "validate_sample_type_rule"
    )
  }

  tibble::as_tibble(rule)
}

#' Build a sample result record.
#'
#' Assembles the two determined kinematic viscosity values (from the two
#' flow-time measurements on the same viscometer, ASTM D445-26 11.2/14.1),
#' checks determinability, and -- if the two values agree -- averages them
#' into a single reported result. This package does not apply a kinetic
#' energy correction; instead, any flow time below `min_flow_time_s` is
#' flagged (`low_flow_time_flag`) so it can be surfaced in reports for
#' operator review (ASTM D445-26 6.1.2/10.2).
#'
#' @param viscometer_id Viscometer identifier.
#' @param sample_type Sample type label (see `.default_sample_rules()`).
#' @param analysis_temperature_c Analysis temperature in C.
#' @param time_1 First measured flow time, s.
#' @param time_2 Second measured flow time, s.
#' @param min_flow_time_s Minimum flow time, s, below which a result is
#'   flagged. Defaults to 200 s (ASTM D445-26 6.1.2/10.2); override with the
#'   viscometer/size-specific minimum from Specifications D446 when it is
#'   higher.
#' @param operator Optional operator name.
#' @param notes Optional notes.
#' @return A list-like result object. If the determinability check fails,
#'   the result is still returned (with `determinability_result == "fail"`)
#'   so the caller/UI can prompt for a repeat measurement per ASTM D445-26
#'   11.2.3/12.4.1 -- `kinvicalc` does not silently average a failing pair.
#' @export
build_sample_result <- function(
  viscometer_id,
  sample_type,
  analysis_temperature_c,
  time_1,
  time_2,
  min_flow_time_s = MIN_FLOW_TIME_S,
  operator = NA_character_,
  notes = NA_character_
) {
  viscometer <- get_viscometer(viscometer_id)
  # NOTE: the viscometer registry still stores separate "top"/"bottom"
  # calibration factors from the original (non-conformant) design; D445/D446
  # do not have a "top bulb" vs "bottom bulb" factor concept -- a viscometer
  # has a single constant C used for both repeat flow-time measurements. This
  # uses the "top" factor for both measurements as a stopgap. See the
  # outstanding-issues summary for the recommended viscometer schema redesign.
  factor <- resolve_calibration_factor(
    viscometer,
    analysis_temperature_c,
    bulb = "top"
  )

  determination_1 <- calculate_kinematic_viscosity(
    time_1,
    factor,
    min_flow_time_s = min_flow_time_s
  )
  determination_2 <- calculate_kinematic_viscosity(
    time_2,
    factor,
    min_flow_time_s = min_flow_time_s
  )

  determinability <- evaluate_determinability(
    sample_type = sample_type,
    analysis_temperature_c = analysis_temperature_c,
    viscosity_1 = determination_1$viscosity,
    viscosity_2 = determination_2$viscosity
  )

  result <- list(
    viscometer_id = viscometer_id,
    viscometer_size = viscometer$viscometer_size[1],
    sample_type = sample_type,
    analysis_temperature_c = analysis_temperature_c,
    time_1 = time_1,
    time_2 = time_2,
    factor = factor,
    low_flow_time_flag = determination_1$low_flow_time_flag ||
      determination_2$low_flow_time_flag,
    kinematic_viscosity_1_cSt = determination_1$viscosity,
    kinematic_viscosity_2_cSt = determination_2$viscosity,
    kinematic_viscosity_cSt = round_half_even(
      determinability$average_viscosity
    ),
    determinability_difference = round_half_even(determinability$difference),
    determinability_result = determinability$result,
    determinability_limit = round_half_even(determinability$limit),
    operator = operator,
    notes = notes,
    created_at = Sys.time()
  )

  if (!determinability$passed) {
    cli::cli_warn(c(
      "{.fn build_sample_result}: determinability check failed for viscometer {.val {viscometer_id}}.",
      "*" = "Observed difference: {format_significant(determinability$difference)} mm2/s.",
      "*" = "Determinability limit: {format_significant(determinability$limit)} mm2/s.",
      "i" = "Per ASTM D445-26 11.2.3/12.4.1, repeat flow-time measurements after cleaning and drying the viscometer before reporting a final result."
    ))
  }

  class(result) <- c("kinvicalc_result", "list")
  result
}
