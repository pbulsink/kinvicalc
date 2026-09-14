# Not part of the package build -- a one-off helper used to capture the
# screenshots embedded in vignettes/kinvicalc_app_tour.Rmd. Re-run this
# after any Shiny UI change to refresh the images.
#
# Requires: shinytest2, chromote, webshot2 (Suggests-only, dev use)
#
# IMPORTANT: shinytest2::AppDriver launches the app in a separate background
# R process (via callr), which does NOT inherit options() set in this
# session. To keep this demo from touching the real local reference
# registry, the temp DB path is set inside a tiny standalone app.R (below)
# rather than via options() in this script.

img_dir <- file.path("vignettes", "images")
dir.create(img_dir, showWarnings = FALSE, recursive = TRUE)

# Isolate this demo run from the real local registry: write a standalone
# app.R into a temp directory that points kinvicalc at a temp SQLite file
# before calling run_app(), and launch shinytest2 against that directory
# rather than against an in-memory shiny.appobj.
demo_dir <- tempfile("kinvicalc-tour-")
dir.create(demo_dir)
demo_db <- file.path(demo_dir, "demo_reference.db")

pkg_root <- normalizePath(".")
writeLines(
  sprintf(
    "options(kinvicalc.reference_db_path = %s)\npkgload::load_all(%s, quiet = TRUE)\nkinvicalc:::run_app()\n",
    deparse(demo_db),
    deparse(pkg_root)
  ),
  file.path(demo_dir, "app.R")
)

app <- shinytest2::AppDriver$new(
  demo_dir,
  name = "kinvicalc-tour",
  height = 900,
  width = 1300,
  load_timeout = 30000
)

snap <- function(filename) {
  app$get_screenshot(file.path(img_dir, filename))
}

# --- 1. Landing view: Calculation tab, nothing entered yet ---------------
Sys.sleep(0.5)
snap("01_calculation_tab_empty.png")

# --- 2. Viscometers tab: empty registry ------------------------------------
app$click(selector = "a[data-value='Viscometers']")
Sys.sleep(0.3)
snap("02_viscometers_tab_empty.png")

# --- 3. Add a viscometer ---------------------------------------------------
app$set_inputs(new_viscometer_size = 200)
app$set_inputs(new_serial_number = "00123")
app$set_inputs(new_factor_40_top = 0.03450)
app$set_inputs(new_factor_40_bottom = 0.03452)
app$set_inputs(new_factor_100_top = 0.03510)
app$set_inputs(new_factor_100_bottom = 0.03512)
app$set_inputs(new_added_by = "J. Analyst")
snap("03_add_viscometer_filled.png")

app$click(selector = "#add_viscometer")
Sys.sleep(0.3)
snap("04_viscometer_registered.png")

# --- 4. Calculation tab: run a sample -------------------------------------
app$click(selector = "a[data-value='Calculation']")
Sys.sleep(0.3)
app$set_inputs(user_id = "J. Analyst")
app$set_inputs(sample_id = "DEMO-001")
app$set_inputs(viscometer_id = "200-00123")
app$set_inputs(sample_type = "kerosine_diesel_biodiesel")
app$set_inputs(analysis_temperature_c = 40)
app$set_inputs(time_1 = 215.4)
app$set_inputs(time_2 = 215.4)
Sys.sleep(0.3)
snap("05_calculation_result.png")

# --- 5. Lock the result -----------------------------------------------------
app$click(selector = "#lock")
Sys.sleep(0.3)
snap("06_result_locked.png")

# --- 6. Reporting tab -------------------------------------------------------
app$click(selector = "a[data-value='Reporting']")
Sys.sleep(0.3)
snap("07_reporting_tab.png")

# --- 7. Standard reference-sample QA/QC check ------------------------------
app$click(selector = "a[data-value='Calculation']")
Sys.sleep(0.3)
app$set_inputs(sample_id = "STD-REF-01")
app$set_inputs(sample_type = "standard")
app$set_inputs(expected_value = 7.46)
app$set_inputs(time_1 = 215.4)
app$set_inputs(time_2 = 215.5)
Sys.sleep(0.3)
snap("08_standard_qaqc_check.png")

# --- 7b. Lock the standard reference result and view it in Reporting -------
app$click(selector = "#lock")
Sys.sleep(0.3)
snap("15_standard_locked.png")

app$click(selector = "a[data-value='Reporting']")
Sys.sleep(0.3)
snap("16_reporting_standard.png")

# --- 7c. A failing standard reference check, for contrast -------------------
# Flow times are kept close together so determinability still passes; the
# expected value is set well away from the measured result so repeatability
# and reproducibility both fail, illustrating the contrast with 08/15/16.
app$click(selector = "a[data-value='Calculation']")
Sys.sleep(0.3)
app$set_inputs(sample_id = "STD-REF-02")
app$set_inputs(sample_type = "standard")
app$set_inputs(expected_value = 8.50)
app$set_inputs(time_1 = 215.4)
app$set_inputs(time_2 = 215.5)
Sys.sleep(0.3)
snap("17_standard_qaqc_fail.png")

# --- 8. Appendix: correct a calibration factor -----------------------------
app$click(selector = "a[data-value='Viscometers']")
Sys.sleep(0.3)
app$set_inputs(new_viscometer_size = 200)
app$set_inputs(new_serial_number = "00123")
app$set_inputs(new_factor_40_top = 0.03448)
app$set_inputs(new_factor_40_bottom = 0.03452)
app$set_inputs(new_factor_100_top = 0.03510)
app$set_inputs(new_factor_100_bottom = 0.03512)
app$set_inputs(new_added_by = "J. Analyst")
app$set_inputs(new_notes = "Corrected factor_40_top typo (was 0.03450).")
Sys.sleep(0.3)
snap("09_update_viscometer_button.png")

app$click(selector = "#add_viscometer")
Sys.sleep(0.3)
snap("10_update_viscometer_confirm.png")

app$click(selector = "#confirm_update_viscometer")
Sys.sleep(0.3)
snap("11_update_viscometer_applied.png")

# --- 9. Appendix: mark cleaning ---------------------------------------------
app$set_inputs(cleaning_viscometer_id = "200-00123")
app$click(selector = "#mark_cleaning")
Sys.sleep(0.3)
snap("12_mark_cleaning.png")

# --- 10. Appendix: archive and unarchive ------------------------------------
app$set_inputs(archive_viscometer_id = "200-00123")
app$click(selector = "#archive_viscometer")
Sys.sleep(0.3)
snap("13_archived.png")

app$set_inputs(unarchive_viscometer_id = "200-00123")
app$click(selector = "#unarchive_viscometer")
Sys.sleep(0.3)
snap("14_unarchived.png")

app$stop()
unlink(demo_dir, recursive = TRUE)

message("Screenshots written to ", normalizePath(img_dir))
