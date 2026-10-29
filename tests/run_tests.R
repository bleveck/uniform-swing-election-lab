# Run from the project root: Rscript tests/run_tests.R
library(testthat)
options(sass.cache = FALSE)
source("R/model.R")
source("R/feeds.R")
b <- read.csv("data/house_2024.csv")
p <- read.csv("data/president_2024_current_map.csv")
replay <- read.csv("data/replay.csv")

test_that("the baseline has exactly the voting House and the known 2024 winners", {
  expect_equal(nrow(b), 435L)
  expect_false(anyDuplicated(b$district_id) > 0)
  expect_equal(seat_counts(project_house(b, 0)), c(D = 215L, R = 220L, Tie = 0L))
  expect_equal(sum(!b$contested), 38L)
  expect_equal(b$d_votes[b$district_id == "NY-01"], 181647 + 1893) # fusion lines
  expect_equal(b$d_votes[b$district_id == "MN-03"], 240209) # DFL affiliation
  expect_true(is.na(b$d_votes[b$district_id == "FL-20"])) # unopposed, no invented votes
  expect_equal(nrow(p), 435L)
  expect_setequal(p$district_id, b$district_id)
  expect_true(all(p$d_share_2024 > 0 & p$d_share_2024 < 1))
  red <- read.csv("data/redistricting_comparison.csv")
  expect_equal(red$share_change_pp[grepl("^MO-", red$district_id)], rep(0, 8))
})

test_that("swings have the right sign, units, weights and seat behavior", {
  ids <- c("VA-01", "VA-02")
  small <- b[match(ids, b$district_id), ]
  # Unequal turnout, same swing: vote weighting must not silently enter the model.
  v <- c(1000000, 10000)
  share <- small$d_share_2024 + c(.02, .06)
  x <- data.frame(district_id = ids, d_votes_current = v * share, r_votes_current = v * (1 - share))
  e <- estimate_swing(small, x)
  expect_equal(e$swing_pp, 4, tolerance = 1e-10)
  expect_equal(estimate_swing(small, x, exclude = "VA-02")$swing_pp, 2, tolerance = 1e-10)
  expect_true(is.na(estimate_swing(small, x, min_votes = 2000000)$swing_pp))
  expect_true(is.na(estimate_swing(small, empty_results())$swing_pp))
  counts <- vapply(seq(-10, 10), function(s) seat_counts(project_house(b, s))[["D"]], integer(1))
  expect_true(all(diff(counts) >= 0))
  extreme <- project_house(b, 100)
  expect_true(all(extreme$projected_d_share >= 0 & extreme$projected_d_share <= 1))
  expect_equal(extreme$projected_party[!b$contested], b$winner_2024[!b$contested])
  tied <- small[1, ]; tied$d_share_2024 <- .5
  expect_equal(seat_counts(project_house(tied, 0))[["Tie"]], 1L)
})

test_that("new-map states and mock results do not enter a live House swing", {
  x <- replay[replay$step == 12, names(empty_results())]
  expect_equal(estimate_swing(b, x, live = FALSE)$n, 10L)
  expect_equal(estimate_swing(b, x, live = TRUE)$n, 4L)
  expect_equal(estimate_swing(p, x, live = TRUE)$n, 10L)
  x$is_test <- TRUE
  expect_equal(estimate_swing(p, x, live = TRUE)$n, 0L)
})

test_that("replay snapshots are cumulative and converge to their designed mean", {
  for (id in watch_districts) {
    x <- replay[replay$district_id == id, ]
    expect_true(all(diff(x$d_votes_current) >= 0))
    expect_true(all(diff(x$r_votes_current) >= 0))
  }
  x <- replay[replay$step == 12, ]
  expect_equal(estimate_swing(b, x)$swing_pp, 3, tolerance = .001)
})

test_that("CSV input fails visibly for wrong dates, duplicate rows and malformed votes", {
  x <- read.csv("data/results_template.csv")
  expect_equal(nrow(validate_results(x)), 1L)
  expect_error(validate_results(rbind(x, x)), "Duplicate")
  x$election_date <- "2024-11-05"; expect_error(validate_results(x), "Wrong election")
  x$election_date <- "2026-11-03"
  for (v in c(-1, NA, Inf, 3.5, "oops")) {
    x$d_votes_current <- v
    expect_error(validate_results(x), "Vote counts")
  }
})

test_that("NC real precinct returns reproduce the certified district total", {
  nc <- parse_nc("data/fixtures/nc2024_house01.tsv", "2024-11-05")
  expect_equal(nc$d_votes_current, 186341)
  expect_equal(nc$r_votes_current, 180034)
  zipped <- parse_nc("data/fixtures/nc2024_house01.zip", "2024-11-05")
  expect_equal(zipped$d_votes_current, nc$d_votes_current)
  expect_error(parse_nc("data/fixtures/nc2024_house01.tsv"), "Wrong NC election")
})

test_that("VA reads statewide totals only, not breakdowns or child localities", {
  va <- parse_va("data/fixtures/va2026_pre_election.json")
  expect_equal(nrow(va), 11L)
  raw <- jsonlite::fromJSON("data/fixtures/va2026_pre_election.json", simplifyVector = FALSE)
  raw$results$ballotItems[[1]]$ballotOptions[[1]]$voteCount <- 11000
  raw$results$ballotItems[[1]]$ballotOptions[[2]]$voteCount <- 9000
  raw$results$ballotItems[[1]]$ballotOptions[[1]]$groupResults[[1]]$voteCount <- 11000
  raw$results$localities <- list(raw$results) # duplicate breakdown must be ignored
  f <- tempfile(fileext = ".json"); on.exit(unlink(f))
  jsonlite::write_json(raw, f, auto_unbox = TRUE, null = "null")
  x <- parse_va(f)
  expect_equal(x$d_votes_current[x$district_id == "VA-01"], 11000)
  expect_equal(x$r_votes_current[x$district_id == "VA-01"], 9000)
})

test_that("Ohio excludes mocks and never adds county totals to district totals", {
  oh <- parse_oh("data/fixtures/oh2026_mock.xml")
  expect_equal(nrow(oh), 15L)
  expect_true(all(oh$is_test))
  doc <- xml2::read_xml("data/fixtures/oh2026_mock.xml")
  ns <- c(n = "http://grouper.ieee.org/groups/1622/groups/2/V1/1622_2-election_results_reporting.xsd")
  contest <- xml2::xml_find_first(doc, ".//n:Contest[starts-with(@Name, 'Representative to Congress')]", ns)
  selection <- xml2::xml_find_first(contest, "./n:BallotSelection", ns)
  counts <- xml2::xml_find_all(selection, "./n:VoteCountsCollection/n:VoteCounts[@Type='Total']", ns)
  xml2::xml_set_attr(counts, "Count", "100") # county and district both say 100
  f <- tempfile(fileext = ".xml"); on.exit(unlink(f)); xml2::write_xml(doc, f)
  x <- parse_oh(f)
  row <- x[x$district_id == "OH-01", ]
  expect_equal(row$d_votes_current + row$r_votes_current, 100) # not 400
})

test_that("Shiny server handles replay, exclusions, no data, and baseline changes", {
  app_env <- new.env(parent = globalenv())
  sys.source("app.R", envir = app_env)
  shiny::testServer(app_env$server, {
    session$setInputs(mode = "replay", baseline = "house", step = 6, min_votes = 1000, exclude = character())
    expect_equal(estimate()$n, 10L)
    expect_equal(seat_counts(projection())[["D"]], 231L)
    session$setInputs(exclude = "KY-06")
    expect_equal(estimate()$n, 9L)
    session$setInputs(step = 0)
    expect_equal(estimate()$n, 0L)
    session$setInputs(mode = "live", baseline = "president", exclude = character())
    expect_equal(nrow(results()), 0L)
    expect_equal(nrow(baseline()), 435L)
    expect_equal(estimate()$n, 0L)
  })
})

test_that("a failed provider retains its last good totals and successful snapshots replace totals", {
  app_env <- new.env(parent = globalenv())
  sys.source("app.R", envir = app_env)
  phase <- 1
  app_env$fetch_feed <- function(state) {
    if (phase == 2 && state == "VA") stop("simulated network outage")
    id <- c(VA = "VA-01", NC = "NC-01", OH = "OH-09")[[state]]
    validate_results(data.frame(district_id = id, d_votes_current = if (phase == 1) 4000 else 5000,
      r_votes_current = 6000, election_date = "2026-11-03"))
  }
  shiny::testServer(app_env$server, {
    session$setInputs(mode = "live", baseline = "president", min_votes = 1000, exclude = character())
    refresh_live()
    expect_equal(nrow(live_data()), 3L)
    expect_true(all(live_data()$d_votes_current == 4000))
    phase <<- 2
    refresh_live()
    expect_equal(live_data()$d_votes_current[live_data()$district_id == "VA-01"], 4000)
    expect_true(all(live_data()$d_votes_current[live_data()$district_id != "VA-01"] == 5000))
    expect_match(statuses(), "STALE")
  })
})
source("tests/test_bayes.R")
source("tests/test_introduction.R")
source("tests/test_ca13.R")
source("tests/test_presidential.R")
source("tests/test_collector.R")
cat("\nAll model, historical prior, Bayesian update, presidential reference, introduction, CA-13 history, feed, collector, and Shiny tests passed.\n")
