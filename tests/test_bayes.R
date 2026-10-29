source("R/bayes.R")
history <- read.csv("data/historical_midterms.csv")
prior <- fit_midterm_prior(history, "R")

test_that("history starts in 1946 and excludes post-census cycles and changed-map states", {
  expect_equal(history$year[history$included], c(1946, 1950, 1954, 1958, 1966, 1970, 1974, 1978, 1986, 1990, 1994, 1998, 2006, 2010, 2014, 2018))
  expect_equal(history$year[!history$included], c(1962, 1982, 2002, 2022))
  expect_equal(prior$n_elections, 16L)
  expect_equal(prior$mean_pp, mean(history$against_president_pp[history$included]))
  expect_equal(prior$sd_pp, sd(history$against_president_pp[history$included]))
  expect_gt(prior$sd_pp, sd(history$against_president_pp[history$included]) / sqrt(16))
  audit <- read.csv("data/historical_pair_audit.csv")
  used <- audit[audit$included, ]
  expect_true(all(used$d_share_previous > 0 & used$d_share_previous < 1 & used$d_share_current > 0 & used$d_share_current < 1))
  expect_false(any(used$year %% 10 == 2))
  expect_false(any(used$year == 2018 & used$state == "pennsylvania"))
  expect_true(any(audit$year == 2018 & audit$state == "pennsylvania" & audit$reason == "New boundary vintage in state"))
  for (y in unique(used$year)) {
    expect_equal(mean(used$against_president_pp[used$year == y]), history$against_president_pp[history$year == y])
  }
})

test_that("historical signs follow the president's party and permit incumbent-party gains", {
  h <- history[history$included, ]
  expect_equal(h$against_president_pp[h$president_party == "R"], h$d_swing_pp[h$president_party == "R"])
  expect_equal(h$against_president_pp[h$president_party == "D"], -h$d_swing_pp[h$president_party == "D"])
  expect_lt(h$against_president_pp[h$year == 1998], 0)
  democratic_president <- fit_midterm_prior(history, "D")
  expect_equal(democratic_president$mean_pp, -prior$mean_pp)
  expect_equal(democratic_president$sd_pp, prior$sd_pp)
})

test_that("Normal conjugacy agrees with a hand-calculated example and numerical integration", {
  simple <- list(mean_pp = 4, sd_pp = 2, district_sd_pp = 3)
  post <- normal_swing_update(-2, 1, simple)
  expect_equal(post$data_weight, 4 / 13)
  expect_equal(post$mean_pp, (9 * 4 + 4 * -2) / 13)
  expect_equal(post$sd_pp^2, 36 / 13)
  kernel <- function(theta) dnorm(theta, 4, 2) * dnorm(-2, theta, 3)
  norm <- integrate(kernel, -Inf, Inf)$value
  expect_equal(integrate(function(theta) theta * kernel(theta), -Inf, Inf)$value / norm, post$mean_pp, tolerance = 1e-7)
  expect_equal(integrate(function(theta) (theta - post$mean_pp)^2 * kernel(theta), -Inf, Inf)$value / norm, post$sd_pp^2, tolerance = 1e-7)
})

test_that("no data returns the prior and more districts reduce its weight", {
  none <- normal_swing_update(NA_real_, 0, prior)
  one <- normal_swing_update(0, 1, prior)
  ten <- normal_swing_update(0, 10, prior)
  expect_equal(none$mean_pp, prior$mean_pp)
  expect_equal(none$sd_pp, prior$sd_pp)
  expect_true(none$prior_only)
  expect_equal(none$prior_weight, 1)
  expect_gt(one$prior_weight, ten$prior_weight)
  expect_gt(one$sd_pp, ten$sd_pp)
  expect_equal(one$data_se_pp, prior$district_sd_pp)
  expect_equal(ten$data_se_pp^2, one$data_se_pp^2 / 10)
  expect_true(ten$mean_pp > 0 && ten$mean_pp < prior$mean_pp)
  diffuse <- normal_swing_update(0, 10, prior, prior_sd_multiplier = 3)
  expect_lt(diffuse$prior_weight, ten$prior_weight)
  expect_error(normal_swing_update(NA, 1, prior), "observed mean")
  expect_error(normal_swing_update(0, -1, prior), "district count")
})

test_that("Bayesian Shiny selection drives seats and replaces cumulative snapshots", {
  app_env <- new.env(parent = globalenv()); sys.source("app.R", envir = app_env)
  shiny::testServer(app_env$server, {
    session$setInputs(mode = "replay", baseline = "house", step = 0, min_votes = 1000,
      exclude = character(), estimator = "bayes", prior_scale = 1)
    expect_equal(estimate()$n, 0L)
    expect_equal(selected_swing(), app_env$historical_prior$mean_pp)
    expect_true(bayesian()$prior_only)
    session$setInputs(step = 1)
    expect_equal(estimate()$n, 1L)
    early_weight <- bayesian()$prior_weight
    session$setInputs(step = 6)
    expect_equal(bayesian()$n, 10L)
    expect_equal(bayesian()$data_se_pp, app_env$historical_prior$district_sd_pp / sqrt(10))
    expect_lt(bayesian()$prior_weight, early_weight)
    expect_equal(selected_swing(), bayesian()$mean_pp)
    expect_equal(seat_counts(projection()), seat_counts(project_house(baseline(), bayesian()$mean_pp)))
    middle <- bayesian()
    session$setInputs(step = 12)
    expect_equal(bayesian()$n, 10L) # not 1 + ... + all earlier snapshots
    expect_equal(bayesian()$prior_weight, middle$prior_weight)
    session$setInputs(estimator = "raw")
    expect_equal(selected_swing(), estimate()$swing_pp)
    session$setInputs(mode = "live", baseline = "president", estimator = "bayes")
    expect_true(bayesian()$prior_only)
    expect_equal(selected_swing(), app_env$pres_prior$mean_pp)
    expect_false(isTRUE(all.equal(active_prior()$mean_pp, app_env$historical_prior$mean_pp)))
  })
})

test_that("prior, likelihood and posterior plots render, including a prior-only state", {
  source("R/plots.R")
  post <- normal_swing_update(1, 3, prior)
  expect_no_error(ggplot2::ggplot_build(bayes_density_plot(post, 1)))
  expect_no_error(ggplot2::ggplot_build(bayes_density_plot(normal_swing_update(NA, 0, prior), NA)))
  expect_no_error(ggplot2::ggplot_build(history_prior_plot(history, prior)))
})
