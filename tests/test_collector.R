source("R/collector.R")
source("scripts/collector_functions.R")

collector_fixture <- function(time = "2026-10-27T00:00:00Z", votes = 1000) {
  clock <- function() collector_time(time)
  fetch <- function(state) {
    ids <- watch_districts[substr(watch_districts, 1, 2) == state]
    validate_results(data.frame(district_id = ids, d_votes_current = votes,
      r_votes_current = 1200, election_date = "2026-11-03"))
  }
  collect_results(fetch = fetch, clock = clock)
}

test_that("collector snapshots round-trip and preparation totals cannot become observations later", {
  x <- collector_fixture()
  f <- tempfile(); on.exit(unlink(f))
  expect_silent(write_collector_snapshot(x, f))
  y <- read_collector_snapshot(f, collector_time("2026-11-03T23:30:00Z"))
  expect_equal(nrow(y$results), 9L)
  expect_true(all(y$results$is_test))
  expect_equal(y$results$d_votes_current, rep(1000, 9))
  x$results$is_test <- FALSE
  expect_true(all(validate_collector_snapshot(x, collector_time("2026-11-03T23:30:00Z"))$results$is_test))
  actual <- collector_fixture("2026-11-03T23:15:00Z")
  expect_false(any(actual$results$is_test))
  actual$results$source_updated_at <- "2026-11-03T23:10:00Z"
  expect_match(collector_status_text(actual, collector_time("2026-11-03T23:16:00Z")), "Provider timestamp: 2026-11-03T23:10:00Z", fixed = TRUE)
})

test_that("one provider outage preserves only its previous cumulative totals and clocks", {
  first <- collector_fixture("2026-11-03T23:15:00Z")
  fresh <- collector_fixture("2026-11-03T23:20:00Z", votes = 2000)
  fetch <- function(state) {
    if (state == "VA") stop("network error with a private /Users/example/file path")
    fresh$results[substr(fresh$results$district_id, 1, 2) == state, ]
  }
  expect_message(second <- collect_results(first, fetch = fetch,
    clock = function() collector_time("2026-11-03T23:20:00Z")), "network error")
  va <- substr(second$results$district_id, 1, 2) == "VA"
  expect_true(all(second$results$d_votes_current[va] == 1000))
  expect_true(all(second$results$d_votes_current[!va] == 2000))
  expect_equal(second$providers$last_success_at[second$providers$provider == "VA"], "2026-11-03T23:15:00Z")
  expect_match(collector_status_text(second, collector_time("2026-11-03T23:20:00Z")), "VA: STALE")
  expect_false(grepl("/Users/", collector_json(second), fixed = TRUE))
  expect_match(collector_status_text(second, collector_time("2026-11-03T23:40:00Z")), "STALE · Laptop")
  expect_match(collector_status_text(second, collector_time("2026-11-03T23:21:00Z"), "download failed"), "Last loaded snapshot retained")
})

test_that("collector rejects malformed, incomplete, duplicate, and future snapshots", {
  x <- collector_fixture()
  bad <- x; bad$schema_version <- 99; expect_error(validate_collector_snapshot(bad), "schema")
  bad <- x; bad$election_date <- "2024-11-05"; expect_error(validate_collector_snapshot(bad), "schema")
  bad <- x; bad$generated_at <- "tomorrow"; expect_error(validate_collector_snapshot(bad), "timestamp")
  bad <- x; bad$generated_at <- "2099-01-01T00:00:00Z"; expect_error(validate_collector_snapshot(bad), "future")
  bad <- x; bad$results$d_votes_current[1] <- -1; expect_error(validate_collector_snapshot(bad), "Vote counts")
  bad <- x; bad$results <- rbind(bad$results, bad$results[1, ]); expect_error(validate_collector_snapshot(bad), "Duplicate")
  bad <- x; bad$results <- bad$results[-1, ]; expect_error(validate_collector_snapshot(bad), "incomplete")
  bad <- x; bad$providers <- bad$providers[-1, ]; expect_error(validate_collector_snapshot(bad), "provider table")
  bad <- x; bad$results$fetched_at[1] <- NA; expect_error(validate_collector_snapshot(bad), "retrieval")
})

test_that("an all-provider failure still produces an explicit empty, valid status snapshot", {
  expect_message(x <- collect_results(fetch = function(state) stop("offline")), "offline")
  expect_equal(nrow(x$results), 0L)
  f <- tempfile(); on.exit(unlink(f)); write_collector_snapshot(x, f)
  expect_equal(nrow(read_collector_snapshot(f)$results), 0L)
  expect_true(all(x$providers$status[x$providers$provider != "KY"] == "error"))
})

test_that("unchanged manual KY data retain the file's entry time", {
  f <- tempfile(fileext = ".csv"); on.exit(unlink(f))
  write.csv(data.frame(district_id = "KY-06", d_votes_current = 4000,
    r_votes_current = 5000, election_date = "2026-11-03"), f, row.names = FALSE)
  Sys.setFileTime(f, collector_time("2026-10-27T00:01:00Z"))
  x <- collect_results(collector_fixture(), ky_file = f,
    fetch = function(state) collector_fixture()$results[substr(collector_fixture()$results$district_id, 1, 2) == state, ],
    clock = function() collector_time("2026-10-27T00:05:00Z"))
  expect_equal(nrow(x$results), 10L)
  expect_equal(x$results$fetched_at[x$results$district_id == "KY-06"], "2026-10-27T00:01:00Z")
  expect_equal(x$providers$last_success_at[x$providers$provider == "KY"], "2026-10-27T00:01:00Z")
})

test_that("initial publishing creates a data-only root branch without changing main", {
  calls <- list()
  api <- function(endpoint, method = "GET", body = NULL, allow_404 = FALSE) {
    calls[[length(calls) + 1L]] <<- list(endpoint = endpoint, method = method, body = body)
    if (method == "GET") return(NULL)
    list(sha = if (grepl("/trees$", endpoint)) "tree-sha" else "commit-sha")
  }
  expect_equal(publish_collector_snapshot(collector_fixture(), api), "commit-sha")
  expect_setequal(vapply(calls[[2]]$body$tree, function(z) z$path, character(1)), c("latest.json", "README.md"))
  expect_length(calls[[3]]$body$parents, 0L)
  expect_equal(calls[[4]]$body$ref, "refs/heads/codex/snapshots")
  expect_false(any(vapply(calls, function(z) grepl("heads/main", z$endpoint, fixed = TRUE), logical(1))))
})

test_that("snapshot updates use a file SHA and cannot roll a newer publication backwards", {
  remote <- collector_fixture()
  puts <- list()
  api <- function(endpoint, method = "GET", body = NULL, allow_404 = FALSE) {
    if (grepl("/git/ref/", endpoint)) return(list(object = list(sha = "old-commit")))
    if (method == "GET") return(list(sha = "old-blob", content = jsonlite::base64_enc(charToRaw(collector_json(remote)))))
    puts[[length(puts) + 1L]] <<- body
    list(commit = list(sha = "new-commit"))
  }
  expect_equal(publish_collector_snapshot(collector_fixture("2026-10-27T00:05:00Z"), api), "new-commit")
  expect_equal(puts[[1]]$sha, "old-blob")
  expect_equal(puts[[1]]$branch, "codex/snapshots")
  remote$generated_at <- "2026-10-27T00:10:00Z"
  expect_error(publish_collector_snapshot(collector_fixture(), api), "newer snapshot")
  expect_length(puts, 1L)
})

test_that("Shiny uses shared data, keeps it after read errors, and never calls the states", {
  env <- new.env(parent = globalenv()); sys.source("app.R", envir = env)
  fixture <- collector_fixture()
  fixture$results$is_test <- FALSE # Mock already-validated election-night data for server arithmetic.
  fail <- FALSE
  env$fetch_collector_snapshot <- function(...) {if (fail) stop("file unavailable"); fixture}
  env$fetch_feed <- function(...) stop("The hosted shared-data mode must not call a state feed.")
  shiny::testServer(env$server, {
    session$setInputs(mode = "collector", auto_collector = FALSE, baseline = "president", min_votes = 1000,
      exclude = character(), estimator = "bayes", prior_scale = 1)
    expect_equal(nrow(results()), 9L)
    expect_equal(estimate()$n, 9L)
    expect_false(bayesian()$prior_only)
    fail <<- TRUE
    refresh_shared()
    expect_equal(nrow(results()), 9L)
    expect_match(shared_error(), "Could not load")
    session$setInputs(mode = "replay", step = 6)
    expect_equal(estimate()$n, 10L)
  })
})
