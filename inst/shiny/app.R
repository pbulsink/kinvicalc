# Standalone launcher for the kinvicalc Shiny app.
#
# This is the only file in the project that may be run via Positron/RStudio's
# "Run App" button, shiny::runApp(), or a Shiny Server / shinyapps.io deploy.
#
# It deliberately contains no application logic. All UI and server code lives
# in the package namespace (R/app.R), so every internal helper resolves
# correctly. Do NOT copy app code here, and do NOT make R/app.R itself
# runnable -- evaluating that file outside the package namespace is what
# caused the recurring 'could not find function "format_viscometer_id"' error.
# See tests/testthat/test-app-source-integrity.R.

library(kinvicalc)

kinvicalc::run_app()
