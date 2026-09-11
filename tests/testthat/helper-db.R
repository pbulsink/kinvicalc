with_test_reference_db <- function(code) {
  db_path <- file.path(tempdir(), sprintf("kinvicalc-test-%s.db", Sys.getpid()))
  if (file.exists(db_path)) {
    unlink(db_path)
  }

  old_option <- getOption("kinvicalc.reference_db_path")
  options(kinvicalc.reference_db_path = db_path)
  on.exit(
    {
      options(kinvicalc.reference_db_path = old_option)
      if (file.exists(db_path)) {
        unlink(db_path)
      }
    },
    add = TRUE
  )

  eval.parent(substitute(code))
}

cleanup_test_viscometer <- function(viscometer_id) {
  if (exists("remove_viscometer", mode = "function")) {
    try(remove_viscometer(viscometer_id), silent = TRUE)
  }
  invisible(TRUE)
}

add_test_viscometer <- function(viscometer) {
  cleanup_test_viscometer(viscometer$viscometer_id[1])
  add_viscometer(viscometer)
  invisible(viscometer)
}
