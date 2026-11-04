source("scripts/ky_ap_feed.R")

ky_ap_fixture <- function() parse_ky_ap("data/fixtures/ky_ap/summary.json",
  "data/fixtures/ky_ap/metadata.json", collector_time("2026-11-04T01:25:00Z"))

test_that("AP statewide candidate totals match the panel and exclude third parties and vote components", {
  x <- ky_ap_fixture()
  expect_equal(x$district_id, "KY-06")
  expect_equal(x$d_votes_current, 33031)
  expect_equal(x$r_votes_current, 42528)
  expect_equal(x$source, "AP via WEKU public KY-06 panel")
  expect_equal(x$source_updated_at, "2026-11-04T01:21:55Z")
  expect_false(x$is_test)
  calls <- character()
  download <- function(url, extension) {
    calls <<- c(calls, url)
    target <- tempfile(fileext = extension)
    file.copy(file.path("data/fixtures/ky_ap", basename(url)), target)
    list(path = target)
  }
  expect_equal(fetch_ky_ap(collector_time("2026-11-04T01:25:00Z"), download), x)
  expect_equal(calls, paste0(ky_ap_config$base, c("metadata.json", "summary.json")))
})

test_that("AP identity, units, counts, candidate joins, test flags and publication clocks are checked", {
  s <- jsonlite::read_json("data/fixtures/ky_ap/summary.json")
  m <- jsonlite::read_json("data/fixtures/ky_ap/metadata.json")
  parse <- function(summary = s, metadata = m) {
    files <- c(tempfile(fileext = ".json"), tempfile(fileext = ".json"))
    on.exit(unlink(files))
    jsonlite::write_json(summary, files[1], auto_unbox = TRUE, null = "null")
    jsonlite::write_json(metadata, files[2], auto_unbox = TRUE, null = "null")
    parse_ky_ap(files[1], files[2], collector_time("2026-11-04T01:25:00Z"))
  }
  bad <- m; bad$electionDate <- "2024-11-05"; expect_error(parse(metadata = bad), "metadata")
  bad <- m; bad$seatNum <- "1"; expect_error(parse(metadata = bad), "metadata")
  bad <- m; bad$officeID <- "S"; expect_error(parse(metadata = bad), "metadata")
  bad <- s; bad$raceID <- "20261103KY18783"; expect_error(parse(bad), "metadata")
  bad <- s; bad$level <- "county"; expect_error(parse(bad), "statewide")
  bad <- s; bad$candidates <- c(bad$candidates, bad$candidates[1]); expect_error(parse(bad), "Duplicate")
  bad <- s; bad$candidates[[1]]$candidateID <- "unknown"; expect_error(parse(bad), "unknown")
  bad <- s; bad$candidates <- bad$candidates[-2]; expect_error(parse(bad), "Democratic")
  bad <- s; bad$candidates[[1]]$voteCount <- -1; expect_error(parse(bad), "vote counts")
  bad <- s; bad$candidates[[1]]$voteCount <- 3.5; expect_error(parse(bad), "vote counts")
  bad <- s; bad$candidates[[1]]$voteCount <- NULL; expect_error(parse(bad), "vote counts")
  bad <- s; bad$test <- NULL; expect_error(parse(bad), "live/test")
  bad <- s; bad$resultsType <- "unknown"; expect_error(parse(bad), "live/test")
  bad <- s; bad$lastUpdated <- "tomorrow"; expect_error(parse(bad), "timestamp")
  bad <- s; bad$lastUpdated <- "2026-11-04T02:00:00Z"; expect_error(parse(bad), "future")
  test <- s; test$test <- TRUE; expect_true(parse(test)$is_test)
  test <- s; test$lastUpdated <- "2026-11-03T22:59:00Z"; expect_true(parse(test)$is_test)
})

test_that("AP failures and older publications retain Kentucky totals without stopping other states", {
  clock <- function() collector_time("2026-11-04T01:25:00Z")
  first <- collector_fixture("2026-11-04T01:25:00Z")
  fetch <- function(state) first$results[substr(first$results$district_id, 1, 2) == state, ]
  x <- collect_results(first, fetch = fetch, clock = clock, fetch_ky = ky_ap_fixture)
  expect_equal(nrow(x$results), 10L)
  expect_equal(x$providers$status[x$providers$provider == "KY"], "ok")
  old_ky <- x$results[x$results$district_id == "KY-06", ]
  expect_equal(old_ky$d_votes_current, 33031)
  expect_message(y <- collect_results(x, fetch = fetch, clock = clock,
    fetch_ky = function() stop("AP offline /Users/private/example")), "AP offline")
  expect_equal(y$results[y$results$district_id == "KY-06", ], old_ky)
  expect_match(collector_status_text(y, clock()), "KY: STALE")
  expect_false(grepl("/Users/", collector_json(y), fixed = TRUE))
  older <- function() {z <- ky_ap_fixture(); z$source_updated_at <- "2026-11-04T01:20:00Z"; z}
  expect_message(z <- collect_results(x, fetch = fetch, clock = clock, fetch_ky = older), "older")
  expect_equal(z$results[z$results$district_id == "KY-06", ], old_ky)
  expect_true(all(z$providers$status[z$providers$provider != "KY"] == "ok"))
  expect_error(collect_results(ky_file = "x.csv", fetch_ky = ky_ap_fixture), "one Kentucky source")
})
