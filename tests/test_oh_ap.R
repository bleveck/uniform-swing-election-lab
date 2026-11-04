source("scripts/oh_ap_feed.R")

oh_ap_download <- function(url, extension) {
  race <- sub(".*/OH/([^/]+)/.*", "\\1", url)
  id <- names(oh_ap_races)[match(race, oh_ap_races)]
  if (is.na(id)) stop("Unexpected AP race URL.")
  path <- tempfile(fileext = extension)
  file.copy(file.path("data/fixtures/oh_ap", id, basename(url)), path)
  list(path = path)
}
oh_ap_fixture <- function() fetch_oh_ap(collector_time("2026-11-04T03:15:00Z"), oh_ap_download)

test_that("Ohio AP reads exactly the four House races and joins candidate parties correctly", {
  calls <- character()
  download <- function(url, extension) {
    calls <<- c(calls, url)
    oh_ap_download(url, extension)
  }
  x <- fetch_oh_ap(collector_time("2026-11-04T03:15:00Z"), download)
  expect_equal(x$district_id, c("OH-07", "OH-09", "OH-10", "OH-15"))
  expect_equal(x$d_votes_current, c(98648, 58735, 118361, 112674))
  expect_equal(x$r_votes_current, c(82799, 86534, 107895, 102515))
  expect_false(any(x$is_test))
  expect_true(all(x$source == "AP via Signal Ohio public House panel"))
  expect_equal(x$source_updated_at, c("2026-11-04T03:05:31Z", "2026-11-04T03:01:36Z",
    "2026-11-04T03:05:48Z", "2026-11-04T03:10:03Z"))
  expect_equal(calls, unlist(lapply(oh_ap_config, function(z)
    paste0(z$base, c("metadata.json", "summary.json"))), use.names = FALSE))
  # A different district's valid files cannot silently substitute for OH-07.
  expect_error(parse_ap_house("data/fixtures/oh_ap/OH-09/summary.json",
    "data/fixtures/oh_ap/OH-09/metadata.json", oh_ap_config[["OH-07"]],
    collector_time("2026-11-04T03:15:00Z")), "OH-07")
})

test_that("Ohio AP collection skips SOS and retains all four races and clocks on any failure", {
  clock <- function() collector_time("2026-11-04T03:20:00Z")
  initial <- collector_fixture("2026-11-04T03:15:00Z")
  fetch <- function(state) {
    if (state == "OH") stop("Must not contact Ohio SOS when AP is selected.")
    initial$results[substr(initial$results$district_id, 1, 2) == state, ]
  }
  x <- collect_results(initial, fetch = fetch, clock = clock, fetch_ky = ky_ap_fixture,
    fetch_oh = oh_ap_fixture)
  expect_equal(nrow(x$results), 10L)
  expect_equal(x$providers$status[x$providers$provider == "OH"], "ok")
  oh <- substr(x$results$district_id, 1, 2) == "OH"
  old <- x$results[oh, ]
  failed <- function() fetch_oh_ap(clock(), function(url, extension) {
    if (grepl(oh_ap_races[["OH-09"]], url, fixed = TRUE)) stop("AP race offline /Users/private/example")
    oh_ap_download(url, extension)
  })
  expect_message(y <- collect_results(x, fetch = fetch, clock = clock,
    fetch_ky = ky_ap_fixture, fetch_oh = failed), "AP race offline")
  expect_equal(y$results[oh, ], old)
  expect_equal(y$providers$last_success_at[y$providers$provider == "OH"],
    x$providers$last_success_at[x$providers$provider == "OH"])
  expect_match(collector_status_text(y, clock()), "OH: STALE")
  expect_true(all(y$providers$status[y$providers$provider != "OH"] == "ok"))
  expect_false(grepl("/Users/", collector_json(y), fixed = TRUE))
  older <- function() {
    z <- oh_ap_fixture()
    z$source_updated_at[z$district_id == "OH-09"] <- "2026-11-04T03:00:00Z"
    z
  }
  expect_message(z <- collect_results(x, fetch = fetch, clock = clock,
    fetch_ky = ky_ap_fixture, fetch_oh = older), "older")
  expect_equal(z$results[oh, ], old)
  missing <- function() oh_ap_fixture()[-1, ]
  expect_message(z <- collect_results(x, fetch = fetch, clock = clock,
    fetch_ky = ky_ap_fixture, fetch_oh = missing), "omitted")
  expect_equal(z$results[oh, ], old)
})
