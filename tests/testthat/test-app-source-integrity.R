# Structural (source-scanning) regression tests for R/app.R.
#
# These guard a class of bug that behavioural tests cannot catch: inside the
# package namespace every internal helper resolves fine, so testServer() passes
# even when the app is broken for the user. The failure only appears when
# R/app.R is evaluated OUTSIDE the namespace -- e.g. Positron's "Run App"
# button, source("R/app.R"), or shiny::runApp("R/app.R") -- where unqualified
# internal calls such as format_viscometer_id() are not visible and the app
# dies with 'could not find function "format_viscometer_id"'.
#
# Two defects caused that, and each is asserted against below.

app_source_path <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "R", "app.R"),
    system.file("R", "app.R", package = "kinvicalc")
  )
  for (path in candidates) {
    if (nzchar(path) && file.exists(path)) {
      return(path)
    }
  }
  NA_character_
}

test_that("R/app.R has no top-level side-effecting code", {
  path <- app_source_path()
  skip_if(is.na(path), "R/app.R source not available (installed package)")

  lines <- readLines(path, warn = FALSE)

  # Top-level lines are those with no leading whitespace. The only legal ones
  # are comments/roxygen, blank lines, closing delimiters of a definition, and
  # `name <- function(` assignments (including backtick-quoted operators like
  # `%||%`). Anything else -- notably `app <- run_app()` -- executes at
  # source() time in the global environment.
  top_level <- lines[grepl("^[^[:space:]]", lines)]
  offenders <- top_level[
    !grepl("^#", top_level) &
      !grepl("^[})]", top_level) &
      !grepl("^`[^`]+` *<- *function", top_level) &
      !grepl("^[a-zA-Z_.][a-zA-Z0-9_.]* *<- *function", top_level)
  ]

  expect_equal(
    offenders,
    character(0),
    info = paste0(
      "R/app.R must not run code at top level; found: ",
      paste(offenders, collapse = " | ")
    )
  )

  # Specifically re-assert the exact line that regressed before.
  expect_false(any(grepl("^app *<- *run_app\\(", lines)))
})

test_that("app.R qualifies every helper defined in another R/ file", {
  path <- app_source_path()
  skip_if(is.na(path), "R/app.R source not available (installed package)")

  r_dir <- dirname(path)
  other_files <- setdiff(
    list.files(r_dir, pattern = "\\.R$", full.names = TRUE),
    path
  )
  skip_if(length(other_files) == 0, "sibling R/ files not available")

  defined_in <- function(file) {
    lines <- readLines(file, warn = FALSE)
    matches <- regmatches(
      lines,
      regexpr("^[a-zA-Z_.][a-zA-Z0-9_.]* *<- *function", lines)
    )
    trimws(sub("<-.*", "", matches))
  }

  other_defined <- unique(unlist(lapply(other_files, defined_in)))
  app_defined <- defined_in(path)

  # Helpers app.R may legitimately call bare: the ones it defines itself.
  candidates <- setdiff(other_defined, app_defined)
  skip_if(length(candidates) == 0, "no cross-file helpers to check")

  app_src <- paste(readLines(path, warn = FALSE), collapse = "\n")
  # Strip comments so prose mentioning helper() in a comment is not flagged.
  app_code <- paste(
    sub("#.*$", "", readLines(path, warn = FALSE)),
    collapse = "\n"
  )

  unqualified <- Filter(
    function(nm) {
      # A call is unqualified if `nm(` appears not preceded by `::`, `$`, or a
      # name character (which would make it a longer identifier).
      grepl(
        sprintf("(^|[^:$a-zA-Z0-9._])%s[ ]*\\(", nm),
        app_code
      )
    },
    candidates
  )

  expect_equal(
    unqualified,
    character(0),
    info = paste0(
      "These helpers live outside R/app.R and must be called as ",
      "kinvicalc::fn() (exported) or kinvicalc:::fn() (internal) so the app ",
      "works when run outside the namespace: ",
      paste(unqualified, collapse = ", ")
    )
  )

  expect_true(nzchar(app_src))
})

test_that("run_app() is exported so the app need not be sourced by file", {
  # If run_app() is not exported, users fall back to source()/Run App on
  # R/app.R, which is exactly the broken path the tests above guard.
  expect_true("run_app" %in% getNamespaceExports("kinvicalc"))
  expect_true(is.function(kinvicalc::run_app))
})

test_that("the shiny launcher delegates to run_app() and holds no app logic", {
  # inst/shiny/app.R is the single file that may be run via runApp() / the
  # "Run App" button. It must stay a thin delegator: if app code is copied
  # into it, that code again evaluates outside the package namespace and
  # reintroduces 'could not find function "format_viscometer_id"'.
  launcher <- testthat::test_path("..", "..", "inst", "shiny", "app.R")
  skip_if(!file.exists(launcher), "launcher not available (installed package)")

  code <- trimws(sub("#.*$", "", readLines(launcher, warn = FALSE)))
  code <- code[nzchar(code)]

  expect_true(any(grepl("kinvicalc::run_app()", code, fixed = TRUE)))

  # Only a library() call and the run_app() call are permitted.
  allowed <- grepl("^library\\(kinvicalc\\)$", code) |
    grepl("^kinvicalc::run_app\\(\\)$", code)
  expect_equal(
    code[!allowed],
    character(0),
    info = "inst/shiny/app.R must only load kinvicalc and call run_app()."
  )

  # And it must genuinely produce an app object for runApp().
  expect_s3_class(shiny::shinyAppFile(launcher), "shiny.appobj")
})
