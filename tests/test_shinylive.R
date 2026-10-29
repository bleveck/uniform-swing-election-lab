source("scripts/build_shinylive.R")

test_that("the browser bundle keeps the same model and reads only shared snapshots", {
  path <- tempfile("browser-bundle-")
  old <- getwd()
  old_options <- options(election_lab.browser = FALSE, sass.cache = FALSE)
  on.exit({setwd(old); options(old_options); unlink(path, recursive = TRUE)})
  stage_shinylive(path)
  expect_false(file.exists(file.path(path, "R/feeds.R")))
  expect_false(dir.exists(file.path(path, "scripts")))
  expect_false(dir.exists(file.path(path, "data/raw")))
  setwd(path)
  app <- new.env(parent = globalenv())
  sys.source("app.R", envir = app)
  expect_true(app$browser_runtime)
  expect_setequal(unname(app$results_choices), c("replay", "collector", "csv"))
  expect_equal(nrow(app$pres_baseline), 435L)
  expect_equal(nrow(app$ca13_returns), 31L)
  # A forbidden network path must remain unused, including on a stray live event.
  app$fetch_feed <- function(...) stop("Browser attempted a state feed")
  app$fetch_collector_snapshot <- function() collector_fixture()
  shiny::testServer(app$server, {
    session$setInputs(mode = "replay", baseline = "president", estimator = "bayes",
      step = 6, min_votes = 1000, prior_scale = 1, exclude = character())
    expect_equal(estimate()$swing_pp, 3.102709, tolerance = 1e-6)
    expect_equal(bayesian()$mean_pp, 4.192269, tolerance = 1e-6)
    refresh_live()
    session$setInputs(mode = "collector", auto_collector = FALSE)
    expect_equal(nrow(results()), 9L)
    expect_equal(estimate()$n, 0L) # preparation totals remain excluded
  })
})
