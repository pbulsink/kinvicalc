# Internal utilities and package-local defaults.

.default_reference_db <- function() {
  user_cache_dir <- tools::R_user_dir("kinvicalc", which = "data")
  dir.create(user_cache_dir, recursive = TRUE, showWarnings = FALSE)
  file.path(user_cache_dir, "reference.db")
}

assert_scalar_numeric <- function(x, name) {
  if (length(x) != 1 || !is.numeric(x) || is.na(x)) {
    stop(sprintf("`%s` must be a single numeric value.", name), call. = FALSE)
  }
}

assert_string <- function(x, name, allow_na = FALSE) {
  if (allow_na && is.na(x)) {
    return(invisible(TRUE))
  }

  if (length(x) != 1 || !is.character(x) || is.na(x) || !nzchar(x)) {
    stop(
      sprintf("`%s` must be a single non-empty string.", name),
      call. = FALSE
    )
  }
}

assert_date <- function(x, name) {
  if (length(x) != 1 || !inherits(x, "Date") || is.na(x)) {
    stop(sprintf("`%s` must be a single Date value.", name), call. = FALSE)
  }
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
#' @keywords internal
format_significant <- function(x, digits = 5) {
  if (is.na(x)) {
    return(NA_character_)
  }
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
    ~sample_type                    , ~temp_min_c , ~temp_max_c , ~coefficient_a , ~exponent_b , ~offset , ~notes                                                                                                                                                                    ,
    "base_oil"                      ,          40 ,          40 , 0.0101         , 1           ,       0 , "D445-26 17.2.1: base oils at 40 C (1.01 %)"                                                                                                                              ,
    "base_oil"                      ,         100 ,         100 , 0.0085         , 1           ,       0 , "D445-26 17.2.1: base oils at 100 C (0.85 %)"                                                                                                                             ,
    "formulated_oil"                ,          40 ,          40 , 0.0074         , 1           ,       0 , "D445-26 17.2.1: formulated oils at 40 C (0.74 %)"                                                                                                                        ,
    "formulated_oil"                ,         100 ,         100 , 0.0084         , 1           ,       0 , "D445-26 17.2.1: formulated oils at 100 C (0.84 %)"                                                                                                                       ,
    "formulated_oil"                ,         150 ,         150 , 0.0056         , 1           ,       0 , "D445-26 17.2.1: formulated oils at 150 C (0.56 %)"                                                                                                                       ,
    "petroleum_wax"                 ,         100 ,         100 , 0.0141         , 1.2         ,       0 , "D445-26 17.2.1: petroleum wax at 100 C, 0.0141 x^1.2"                                                                                                                    ,
    "residual_fuel_oil"             ,          50 ,          50 , 0.07885        , 1           ,       0 , "D445-26 17.2.1: residual fuel oils at 50 C (7.88 %)"                                                                                                                     ,
    "residual_fuel_oil"             ,         100 ,         100 , 0.08088        , 1           ,       0 , "D445-26 17.2.1: residual fuel oils at 100 C (8.08 %)"                                                                                                                    ,
    "additive"                      ,         100 ,         100 , 0.00192        , 1.1         ,       0 , "D445-26 17.2.1: additives at 100 C, 0.00192 x^1.1"                                                                                                                       ,
    "gas_oil"                       ,          40 ,          40 , 0.0043         , 1           ,       1 , "D445-26 17.2.1: gas oils at 40 C, 0.0043 (x+1)"                                                                                                                          ,
    "jet_fuel"                      ,         -20 ,         -20 , 0.01850        , 0           ,       0 , "D445-26 17.2.1: jet fuels at -20 C, fixed 0.01850 mm2/s"                                                                                                                 ,
    "jet_fuel"                      ,         -40 ,         -40 , NA_real_       , NA_real_    ,       0 , "UNVERIFIED: D445-26 17.2.1 jet fuels at -40 C table cell could not be unambiguously transcribed (candidates 0.002719 x^1.14 or 0.0056 x); confirm against the standard." ,
    "kerosine_diesel_biodiesel"     ,          40 ,          40 , NA_real_       , NA_real_    ,       0 , "UNVERIFIED: D445-26 17.2.1 kerosine/diesel/biodiesel at 40 C table cell could not be unambiguously transcribed; confirm against the standard."                           ,
    "used_inservice_formulated_oil" ,          15 ,         100 , NA_real_       , NA_real_    ,       0 , "UNVERIFIED: D445-26 17.2.1 used in-service formulated oils table cell could not be unambiguously transcribed; confirm against the standard."
  )

  reproducibility <- tibble::tribble(
    ~sample_type                    , ~temp_min_c , ~temp_max_c , ~coefficient_a , ~exponent_b , ~offset , ~notes                                                                                                                                          ,
    "base_oil"                      ,          40 ,          40 , 0.0136         , 1           ,       0 , "D445-26 17.2.2: base oils at 40 C (1.36 %)"                                                                                                    ,
    "base_oil"                      ,         100 ,         100 , 0.0190         , 1           ,       0 , "D445-26 17.2.2: base oils at 100 C (1.90 %)"                                                                                                   ,
    "formulated_oil"                ,          40 ,          40 , 0.0122         , 1           ,       0 , "D445-26 17.2.2: formulated oils at 40 C (1.22 %)"                                                                                              ,
    "formulated_oil"                ,         100 ,         100 , 0.0138         , 1           ,       0 , "D445-26 17.2.2: formulated oils at 100 C (1.38 %)"                                                                                             ,
    "formulated_oil"                ,         150 ,         150 , 0.018          , 1           ,       0 , "D445-26 17.2.2: formulated oils at 150 C (1.8 %)"                                                                                              ,
    "petroleum_wax"                 ,         100 ,         100 , 0.0366         , 1.2         ,       0 , "D445-26 17.2.2: petroleum wax at 100 C, 0.0366 x^1.2"                                                                                          ,
    "residual_fuel_oil"             ,          50 ,          50 , 0.08461        , 1           ,       0 , "D445-26 17.2.2: residual fuel oils at 50 C (8.46 %)"                                                                                           ,
    "residual_fuel_oil"             ,         100 ,         100 , 0.1206         , 1           ,       0 , "D445-26 17.2.2: residual fuel oils at 100 C (12.06 %)"                                                                                         ,
    "additive"                      ,         100 ,         100 , 0.00862        , 1.1         ,       0 , "D445-26 17.2.2: additives at 100 C, 0.00862 x^1.1"                                                                                             ,
    "gas_oil"                       ,          40 ,          40 , 0.0082         , 1           ,       1 , "D445-26 17.2.2: gas oils at 40 C, 0.0082 (x+1)"                                                                                                ,
    "jet_fuel"                      ,         -20 ,         -20 , 0.04718        , 0           ,       0 , "D445-26 17.2.2: jet fuels at -20 C, fixed 0.04718 mm2/s"                                                                                       ,
    "jet_fuel"                      ,         -40 ,         -40 , NA_real_       , NA_real_    ,       0 , "UNVERIFIED: D445-26 17.2.2 jet fuels at -40 C table cell could not be unambiguously transcribed; confirm against the standard."                ,
    "kerosine_diesel_biodiesel"     ,          40 ,          40 , NA_real_       , NA_real_    ,       0 , "UNVERIFIED: D445-26 17.2.2 kerosine/diesel/biodiesel at 40 C table cell could not be unambiguously transcribed; confirm against the standard." ,
    "used_inservice_formulated_oil" ,          15 ,         100 , NA_real_       , NA_real_    ,       0 , "UNVERIFIED: D445-26 17.2.2 used in-service formulated oils table cell could not be unambiguously transcribed; confirm against the standard."
  )

  determinability$metric <- "determinability"
  repeatability$metric <- "repeatability"
  reproducibility$metric <- "reproducibility"

  tibble::as_tibble(
    rbind(determinability, repeatability, reproducibility)
  )
}


validate_reference_tbl <- function(tbl, expected_cols) {
  missing_cols <- setdiff(expected_cols, names(tbl))
  if (length(missing_cols) > 0) {
    stop(
      sprintf(
        "Reference table is missing required columns: %s",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(tbl)
}
