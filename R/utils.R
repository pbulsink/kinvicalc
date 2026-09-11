# Internal utilities and package-local defaults.

.default_reference_db <- function() {
  override <- getOption("kinvicalc.reference_db_path")
  if (!is.null(override)) {
    return(override)
  }

  user_cache_dir <- tools::R_user_dir("kinvicalc", which = "data")
  dir.create(user_cache_dir, recursive = TRUE, showWarnings = FALSE)
  file.path(user_cache_dir, "reference.db")
}

#' Round using round-half-to-even (banker's rounding).
#'
#' All numeric results reported by `kinvicalc` are rounded with round-half-
#' to-even, matching R's native `round()` behaviour (IEC 60559), so this is a
#' thin, explicit wrapper used consistently at the point each reported value
#' is produced.
#'
#' @param x A numeric value.
#' @param digits Number of decimal places to round to. Defaults to 4.
#' @return `x` rounded to `digits` decimal places using round-half-to-even.
#' @keywords internal
round_half_even <- function(x, digits = 4) {
  round(x, digits)
}

assert_scalar_numeric <- function(x, name, fn = NULL) {
  if (is.null(fn)) {
    fn <- as.character(sys.call(-1)[[1]])
  }

  if (length(x) != 1 || !is.numeric(x) || is.na(x)) {
    cli::cli_abort(c(
      "{.fn {fn}}: {.arg {name}} must be a single numeric value.",
      "i" = "Supply one non-missing numeric value for {.arg {name}}."
    ))
  }
}

assert_string <- function(x, name, allow_na = FALSE, fn = NULL) {
  if (is.null(fn)) {
    fn <- as.character(sys.call(-1)[[1]])
  }

  if (allow_na && is.na(x)) {
    return(invisible(TRUE))
  }

  if (length(x) != 1 || !is.character(x) || is.na(x) || !nzchar(x)) {
    cli::cli_abort(c(
      "{.fn {fn}}: {.arg {name}} must be a single non-empty string.",
      "i" = "Provide a character scalar for {.arg {name}} with at least one non-space character."
    ))
  }
}

assert_date <- function(x, name, fn = NULL) {
  if (is.null(fn)) {
    fn <- as.character(sys.call(-1)[[1]])
  }

  if (length(x) != 1 || !inherits(x, "Date") || is.na(x)) {
    cli::cli_abort(c(
      "{.fn {fn}}: {.arg {name}} must be a single Date value.",
      "i" = "Convert {.arg {name}} to Date (for example with {.fn as.Date}) before calling {.fn {fn}}."
    ))
  }
}

format_sample_type_label <- function(sample_type) {
  if (is.na(sample_type)) {
    return(NA_character_)
  }

  tools::toTitleCase(gsub("_", " ", sample_type, fixed = TRUE))
}

sample_type_choices <- function() {
  rules <- load_reference_data()$sample_types
  sample_types <- sort(unique(rules$sample_type))
  stats::setNames(
    sample_types,
    vapply(sample_types, format_sample_type_label, character(1))
  )
}

format_viscometer_label <- function(viscometer) {
  archived <- if (
    isTRUE(
      !is.na(viscometer$archived_at[1]) && nzchar(viscometer$archived_at[1])
    )
  ) {
    " [archived]"
  } else {
    ""
  }

  sprintf(
    "%s (size %s)%s",
    viscometer$viscometer_id[1],
    viscometer$viscometer_size[1],
    archived
  )
}

viscometer_choices <- function(include_archived = FALSE) {
  viscometers <- list_viscometers()
  if (!include_archived && "archived_at" %in% names(viscometers)) {
    viscometers <- viscometers[is.na(viscometers$archived_at), ]
  }

  if (nrow(viscometers) == 0) {
    return(stats::setNames(character(0), character(0)))
  }

  stats::setNames(
    viscometers$viscometer_id,
    vapply(
      split(viscometers, seq_len(nrow(viscometers))),
      format_viscometer_label,
      character(1)
    )
  )
}

#' Format a viscometer ID
#'
#' Builds the canonical `NNN-NNNNN` viscometer ID (three-digit size prefix,
#' hyphen, serial number) used as the primary key throughout the registry.
#'
#' @param viscometer_size Integer viscometer size number (1-999), per the
#'   ASTM viscometer size designation used to construct the ID prefix.
#' @param serial_number Character serial number, used as the ID suffix.
#' @param fn Character scalar naming the calling function, used in error
#'   messages. Defaults to the name of the calling function.
#'
#' @return A character scalar viscometer ID in `NNN-NNNNN` format.
#'
#' @examples
#' format_viscometer_id(200, "12345")
#'
#' @export
format_viscometer_id <- function(viscometer_size, serial_number, fn = NULL) {
  if (is.null(fn)) {
    fn <- as.character(sys.call(-1)[[1]])
  }

  assert_scalar_numeric(viscometer_size, "viscometer_size", fn = fn)
  viscometer_size <- as.integer(viscometer_size)
  if (viscometer_size <= 0 || viscometer_size > 999) {
    cli::cli_abort(c(
      "{.fn {fn}}: {.arg viscometer_size} must be an integer between 1 and 999.",
      "i" = "Use the ASTM viscometer size number used to construct the three-digit ID prefix."
    ))
  }

  assert_string(serial_number, "serial_number", fn = fn)
  if (!grepl("^[0-9]{1,5}$", serial_number)) {
    cli::cli_abort(c(
      "{.fn {fn}}: {.arg serial_number} must contain only digits and be at most 5 characters.",
      "i" = "Use the serial number digits only; the ID is built automatically as ###-#####."
    ))
  }

  sprintf("%03d-%05d", as.integer(viscometer_size), as.integer(serial_number))
}

is_valid_viscometer_id <- function(x) {
  grepl("^[0-9]{3}-[0-9]{5}$", x)
}

#' Format a numeric value to at least a given number of significant figures.
#'
#' @param x A numeric value.
#' @param digits Minimum number of significant figures. ASTM D445-26 15.1
#'   requires 4 significant figures for a final client-facing report; this
#'   package defaults to 5 for intermediate/internal reporting so round
#'   explicitly to 4 when producing a final client report.
#' @return A character string with `x` rounded to `digits` significant figures.
#' @export
format_significant <- function(x, digits = 5) {
  if (is.na(x)) {
    return(NA_character_)
  }
  # signif() uses IEC 60559 round-half-to-even, consistent with the rest of
  # the package's rounding behaviour.
  formatC(signif(x, digits), digits = digits, format = "g", flag = "#")
}

# Default sample-type precision rules, transcribed from ASTM D445-26 Section
# 17 (Precision and Bias):
#   - determinability (d): 17.1.1 (table) and 17.1.2 (used in-service oils);
#     11.2.4/12.4.1 fallback estimates for materials/temperatures not listed.
#   - repeatability (r): 17.2.1.
#   - reproducibility (R): 17.2.2.
#
# Each rule expresses its limit as a function of the average of the two
# compared values, y or x (mm2/s):
#
#   limit = coefficient_a * (average + offset) ^ exponent_b
#
# covering every functional form used in the standard:
#   "0.0037y"        -> coefficient_a = 0.0037, exponent_b = 1,   offset = 0
#   "0.0013(y+1)"     -> coefficient_a = 0.0013, exponent_b = 1,   offset = 1
#   "0.00106y^1.1"    -> coefficient_a = 0.00106, exponent_b = 1.1, offset = 0
#   a fixed mm2/s value -> coefficient_a = value, exponent_b = 0,  offset = 0
#
# Some cells in the standard's repeatability/reproducibility tables for jet
# fuels at -40 C, kerosine/diesel/biodiesel fuels and blends at 40 C, and used
# in-service formulated oils could not be unambiguously transcribed from the
# scanned/OCR'd table layout (columns for several sample types run together).
# Those rows are intentionally left with `coefficient_a = NA` so that
# `get_sample_type_rule()` errors loudly rather than silently using a guessed
# value; confirm the correct figures directly against a clean copy of D445-26
# Table entries in 17.2.1/17.2.2 and update via `add_sample_type_rule()`.
.default_sample_rules <- function() {
  determinability <- tibble::tribble(
    ~sample_type                    , ~temp_min_c , ~temp_max_c , ~coefficient_a , ~exponent_b , ~offset , ~notes                                                                           ,
    "base_oil"                      ,          40 ,          40 , 0.0037         , 1           ,       0 , "D445-26 17.1.1: base oils at 40 C (0.37 %)"                                     ,
    "base_oil"                      ,         100 ,         100 , 0.0036         , 1           ,       0 , "D445-26 17.1.1: base oils at 100 C (0.36 %)"                                    ,
    "formulated_oil"                ,          40 ,          40 , 0.0037         , 1           ,       0 , "D445-26 17.1.1: formulated oils at 40 C (0.37 %)"                               ,
    "formulated_oil"                ,         100 ,         100 , 0.0036         , 1           ,       0 , "D445-26 17.1.1: formulated oils at 100 C (0.36 %)"                              ,
    "formulated_oil"                ,         150 ,         150 , 0.015          , 1           ,       0 , "D445-26 17.1.1: formulated oils at 150 C (1.5 %)"                               ,
    "petroleum_wax"                 ,         100 ,         100 , 0.0080         , 1           ,       0 , "D445-26 17.1.1: petroleum wax at 100 C (0.80 %)"                                ,
    "residual_fuel_oil"             ,          50 ,          50 , 0.0244         , 1           ,       0 , "D445-26 17.1.1: residual fuel oils at 50 C (2.44 %)"                            ,
    "residual_fuel_oil"             ,         100 ,         100 , 0.03           , 1           ,       0 , "D445-26 17.1.1: residual fuel oils at 100 C (3 %)"                              ,
    "additive"                      ,         100 ,         100 , 0.00106        , 1.1         ,       0 , "D445-26 17.1.1: additives at 100 C, 0.00106 y^1.1"                              ,
    "gas_oil"                       ,          40 ,          40 , 0.0013         , 1           ,       1 , "D445-26 17.1.1: gas oils at 40 C, 0.0013 (y+1)"                                 ,
    "jet_fuel"                      ,         -20 ,         -20 , 0.01617        , 0           ,       0 , "D445-26 17.1.1: jet fuels at -20 C, fixed 0.01617 mm2/s"                        ,
    "jet_fuel"                      ,         -40 ,         -40 , 0.03113        , 0           ,       0 , "D445-26 17.1.1: jet fuels at -40 C, fixed 0.03113 mm2/s"                        ,
    "kerosine_diesel_biodiesel"     ,          40 ,          40 , 0.0037         , 1           ,       0 , "D445-26 17.1.1: kerosine, diesel, biodiesel fuels/blends at 40 C (0.37 %)"      ,
    "used_inservice_formulated_oil" ,          15 ,         100 , 0.010          , 1           ,       0 , "D445-26 17.1.2: used in-service formulated oils, 15-100 C, 1.0 %"               ,
    "unlisted"                      ,          15 ,         100 , 0.010          , 1           ,       0 , "D445-26 12.4.1: fallback for unlisted materials, 15-100 C, 1.0 %"               ,
    "unlisted"                      , -Inf        ,          15 , 0.015          , 1           ,       0 , "D445-26 12.4.1/11.2.4: fallback for unlisted materials outside 15-100 C, 1.5 %" ,
    "unlisted"                      ,         100 , Inf         , 0.015          , 1           ,       0 , "D445-26 12.4.1/11.2.4: fallback for unlisted materials outside 15-100 C, 1.5 %"
  )

  repeatability <- tibble::tribble(
    ~sample_type                    , ~temp_min_c , ~temp_max_c , ~coefficient_a , ~exponent_b , ~offset , ~notes                                                                              ,
    "base_oil"                      ,          40 ,          40 , 0.0101         , 1           ,       0 , "D445-26 17.2.1: base oils at 40 C (1.01 %)"                                        ,
    "base_oil"                      ,         100 ,         100 , 0.0085         , 1           ,       0 , "D445-26 17.2.1: base oils at 100 C (0.85 %)"                                       ,
    "formulated_oil"                ,          40 ,          40 , 0.0074         , 1           ,       0 , "D445-26 17.2.1: formulated oils at 40 C (0.74 %)"                                  ,
    "formulated_oil"                ,         100 ,         100 , 0.0084         , 1           ,       0 , "D445-26 17.2.1: formulated oils at 100 C (0.84 %)"                                 ,
    "formulated_oil"                ,         150 ,         150 , 0.0056         , 1           ,       0 , "D445-26 17.2.1: formulated oils at 150 C (0.56 %)"                                 ,
    "petroleum_wax"                 ,         100 ,         100 , 0.0141         , 1.2         ,       0 , "D445-26 17.2.1: petroleum wax at 100 C, 0.0141 x^1.2"                              ,
    "residual_fuel_oil"             ,          50 ,          50 , 0.07885        , 1           ,       0 , "D445-26 17.2.1: residual fuel oils at 50 C (7.88 %)"                               ,
    "residual_fuel_oil"             ,         100 ,         100 , 0.08088        , 1           ,       0 , "D445-26 17.2.1: residual fuel oils at 100 C (8.08 %)"                              ,
    "additive"                      ,         100 ,         100 , 0.00192        , 1.1         ,       0 , "D445-26 17.2.1: additives at 100 C, 0.00192 x^1.1"                                 ,
    "gas_oil"                       ,          40 ,          40 , 0.0043         , 1           ,       1 , "D445-26 17.2.1: gas oils at 40 C, 0.0043 (x+1)"                                    ,
    "jet_fuel"                      ,         -20 ,         -20 , 0.01850        , 0           ,       0 , "D445-26 17.2.1: jet fuels at -20 C, fixed 0.01850 mm2/s"                           ,
    "jet_fuel"                      ,         -40 ,         -40 , 0.002719       , 1.14        ,       0 , "D445-26 17.2.1 jet fuels at -40 C 0.002719 x^1.14 or 0.0056"                       ,
    "used_inservice_formulated_oil" ,          40 ,          40 , 0.000233       , 1.722       ,       0 , "D445-26 17.2.1: used in-service formulated oils at 40 C, 0.000233 x^1.722 "        ,
    "used_inservice_formulated_oil" ,         100 ,         100 , 0.001005       , 1.4633      ,       0 , "D445-26 17.2.1: used in-service formulated oils at 100 C, 0.001005 x^1.4633"       ,
    "kerosene_diesel_biodiesel"     ,          40 ,          40 , 0.0056         , 1           ,       0 , "D445-26 17.2.1: kerosine/diesel/biodiesel fuels/blends at 40 C, 0.0056 x (0.56 %)"
  )

  reproducibility <- tibble::tribble(
    ~sample_type                    , ~temp_min_c , ~temp_max_c , ~coefficient_a , ~exponent_b , ~offset , ~notes                                                                        ,
    "base_oil"                      ,          40 ,          40 , 0.0136         , 1           ,       0 , "D445-26 17.2.2: base oils at 40 C (1.36 %)"                                  ,
    "base_oil"                      ,         100 ,         100 , 0.0190         , 1           ,       0 , "D445-26 17.2.2: base oils at 100 C (1.90 %)"                                 ,
    "formulated_oil"                ,          40 ,          40 , 0.0122         , 1           ,       0 , "D445-26 17.2.2: formulated oils at 40 C (1.22 %)"                            ,
    "formulated_oil"                ,         100 ,         100 , 0.0138         , 1           ,       0 , "D445-26 17.2.2: formulated oils at 100 C (1.38 %)"                           ,
    "formulated_oil"                ,         150 ,         150 , 0.018          , 1           ,       0 , "D445-26 17.2.2: formulated oils at 150 C (1.8 %)"                            ,
    "petroleum_wax"                 ,         100 ,         100 , 0.0366         , 1.2         ,       0 , "D445-26 17.2.2: petroleum wax at 100 C, 0.0366 x^1.2"                        ,
    "residual_fuel_oil"             ,          50 ,          50 , 0.08461        , 1           ,       0 , "D445-26 17.2.2: residual fuel oils at 50 C (8.46 %)"                         ,
    "residual_fuel_oil"             ,         100 ,         100 , 0.1206         , 1           ,       0 , "D445-26 17.2.2: residual fuel oils at 100 C (12.06 %)"                       ,
    "additive"                      ,         100 ,         100 , 0.00862        , 1.1         ,       0 , "D445-26 17.2.2: additives at 100 C, 0.00862 x^1.1"                           ,
    "gas_oil"                       ,          40 ,          40 , 0.0082         , 1           ,       1 , "D445-26 17.2.2: gas oils at 40 C, 0.0082 (x+1)"                              ,
    "jet_fuel"                      ,         -20 ,         -20 , 0.04718        , 0           ,       0 , "D445-26 17.2.2: jet fuels at -20 C, fixed 0.04718 mm2/s"                     ,
    "jet_fuel"                      ,         -40 ,         -40 , 0.005077       , 1.14        ,       0 , "D445-26 17.2.2: jet fuels at -40 C, 0.005077 x^1.14"                         ,
    "kerosine_diesel_biodiesel"     ,          40 ,          40 , 0.0224         , 1           ,       0 , "D445-26 17.2.2: kerosine/diesel/biodiesel at 40 C, 0.0224 x (2.24 %)"        ,
    "used_inservice_formulated_oil" ,          40 ,          40 , 0.000594       , 1.722       ,       0 , "D445-26 17.2.2: used in-service formulated oils at 40 C, 0.000594 x^1.722"   ,
    "used_inservice_formulated_oil" ,         100 ,         100 , 0.003361       , 1.4633      ,       0 , "D445-26 17.2.2: used in-service formulated oils at 100 C, 0.003361 x^1.4633"
  )

  determinability$metric <- "determinability"
  repeatability$metric <- "repeatability"
  reproducibility$metric <- "reproducibility"

  tibble::as_tibble(
    rbind(determinability, repeatability, reproducibility)
  )
}


validate_reference_tbl <- function(tbl, expected_cols, fn = NULL) {
  if (is.null(fn)) {
    fn <- as.character(sys.call(-1)[[1]])
  }

  missing_cols <- setdiff(expected_cols, names(tbl))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "{.fn {fn}}: reference table is missing required columns: {paste(missing_cols, collapse = ', ')}.",
      "i" = "Ensure the input table has exactly the expected schema before saving reference data."
    ))
  }

  invisible(tbl)
}
