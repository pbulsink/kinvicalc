test_that("viscometer validation accepts valid IDs and rejects invalid ones", {
  with_test_reference_db({
    expect_true(validate_viscometer("001-00001"))
    expect_false(validate_viscometer("bad-id"))
    expect_error(validate_viscometer(1), "viscometer_id")
  })
})

test_that("viscometer registry stores and retrieves records", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 2,
      serial_number = "00002",
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    out <- get_viscometer("002-00002")

    expect_equal(out$viscometer_id[1], "002-00002")
    expect_equal(out$factor_40_top[1], 0.05)
    expect_error(get_viscometer("bad-id"), "must match")
    expect_error(
      add_viscometer(
        tibble::tibble(
          viscometer_size = 2,
          serial_number = "00002",
          status = "active",
          factor_40_top = 0.05,
          factor_40_bottom = 0.06,
          factor_100_top = 0.07,
          factor_100_bottom = 0.08
        )
      ),
      "already exists"
    )
  })
})


test_that("add_viscometer works with the current registry schema", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 12,
      serial_number = "00012",
      status = "active",
      factor_40_top = 0.12,
      factor_40_bottom = 0.13,
      factor_100_top = 0.14,
      factor_100_bottom = 0.15,
      notes = "regression test"
    )

    out <- add_viscometer(viscometer)

    expect_equal(out$viscometer_id[1], "012-00012")
    expect_equal(out$notes[1], "regression test")
    expect_equal(nrow(list_viscometers()), 1)
  })
})

test_that("reference_db_connection migrates legacy viscometer tables additively", {
  with_test_reference_db({
    db_path <- file.path(
      tempdir(),
      sprintf("kinvicalc-test-%s.db", Sys.getpid())
    )
    db <- DBI::dbConnect(RSQLite::SQLite(), db_path)

    DBI::dbExecute(
      db,
      "CREATE TABLE viscometers (
        viscometer_id TEXT PRIMARY KEY,
        viscometer_size NUMERIC,
        serial_number TEXT,
        calibration_date TEXT,
        status TEXT
      )"
    )
    DBI::dbExecute(
      db,
      "INSERT INTO viscometers (viscometer_id, viscometer_size, serial_number, calibration_date, status)
       VALUES ('old-00001', 1, '00001', '2024-01-01', 'active')"
    )
    DBI::dbDisconnect(db)

    viscometer <- tibble::tibble(
      viscometer_size = 19,
      serial_number = "00019",
      status = "active",
      factor_40_top = 0.19,
      factor_40_bottom = 0.20,
      factor_100_top = 0.21,
      factor_100_bottom = 0.22,
      added_by = "fresh-user",
      notes = "rebuilt registry"
    )

    out <- add_viscometer(viscometer)

    expect_equal(out$viscometer_id[1], "019-00019")
    expect_equal(out$added_by[1], "fresh-user")
    expect_equal(out$notes[1], "rebuilt registry")
    # The pre-existing legacy row must survive the schema migration: missing
    # columns are added via ALTER TABLE, the table is never dropped.
    expect_true("old-00001" %in% list_viscometers()$viscometer_id)
    expect_true(all(
      c("viscometer_id", "added_by", "notes", "created_at", "updated_at") %in%
        names(list_viscometers())
    ))

    legacy_row <- list_viscometers()[
      list_viscometers()$viscometer_id == "old-00001",
    ]
    expect_equal(legacy_row$status, "active")
    expect_equal(legacy_row$serial_number, "00001")
  })
})

test_that("archive_viscometer and unarchive_viscometer toggle archived state", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 3,
      serial_number = "00003",
      status = "active",
      factor_40_top = 0.09,
      factor_40_bottom = 0.10,
      factor_100_top = 0.11,
      factor_100_bottom = 0.12
    )

    add_test_viscometer(viscometer)
    archived <- archive_viscometer("003-00003")
    expect_false(is.na(archived$archived_at[1]))
    expect_equal(nrow(list_active_viscometers()), 0)
    expect_equal(nrow(list_archived_viscometers()), 1)

    unarchived <- unarchive_viscometer("003-00003")
    expect_true(is.na(unarchived$archived_at[1]))
    expect_equal(nrow(list_active_viscometers()), 1)
    expect_equal(nrow(list_archived_viscometers()), 0)
  })
})

test_that("remove_viscometer deletes a viscometer record", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 3,
      serial_number = "00003",
      status = "active",
      factor_40_top = 0.09,
      factor_40_bottom = 0.10,
      factor_100_top = 0.11,
      factor_100_bottom = 0.12
    )

    add_test_viscometer(viscometer)
    expect_true(remove_viscometer("003-00003"))
    expect_false(remove_viscometer("003-00003"))
    expect_error(get_viscometer("003-00003"), "no viscometer found")
  })
})

test_that("new viscometers initialize use counters", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 7,
      serial_number = "00007",
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    summary <- get_viscometer_use_summary("007-00007")

    expect_equal(summary$use_count_since_cleaning[1], 0)
    expect_equal(summary$total_use_count[1], 0)
    expect_true(is.na(summary$last_deep_cleaned_at[1]))
    expect_error(get_viscometer_use_summary("bad-id"), "no viscometer found")
  })
})

test_that("increment_viscometer_use increments both counters", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 8,
      serial_number = "00008",
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    increment_viscometer_use("008-00008")
    increment_viscometer_use("008-00008")

    summary <- get_viscometer_use_summary("008-00008")
    expect_equal(summary$use_count_since_cleaning[1], 2)
    expect_equal(summary$total_use_count[1], 2)
    expect_error(increment_viscometer_use("bad-id"), "no viscometer found")
  })
})

test_that("reset_viscometer_use_count resets since-cleaning only", {
  with_test_reference_db({
    viscometer <- tibble::tibble(
      viscometer_size = 9,
      serial_number = "00009",
      status = "active",
      factor_40_top = 0.05,
      factor_40_bottom = 0.06,
      factor_100_top = 0.07,
      factor_100_bottom = 0.08
    )

    add_test_viscometer(viscometer)
    increment_viscometer_use("009-00009")
    increment_viscometer_use("009-00009")
    reset <- reset_viscometer_use_count("009-00009")

    expect_equal(reset$use_count_since_cleaning[1], 0)
    expect_equal(reset$total_use_count[1], 2)
    expect_false(is.na(reset$last_deep_cleaned_at[1]))
    expect_error(reset_viscometer_use_count("bad-id"), "no viscometer found")
  })
})
