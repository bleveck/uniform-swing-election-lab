pres_h <- read.csv("data/historical_president_midterms.csv")
pres_a <- read.csv("data/historical_president_pair_audit.csv")
pres_p <- fit_midterm_prior(pres_h, "R")
pres_r <- read.csv("data/replay_president.csv")

test_that("presidential-reference prior uses its own two-party historical target", {
  expect_equal(pres_h$year[pres_h$included], c(1954,1958,1966,1970,1974,1978,1986,1990,1994,1998,2006,2010,2014,2018))
  expect_equal(pres_p$n_elections, 14L)
  expect_equal(pres_p$mean_pp, 7.16498879, tolerance = 1e-7)
  expect_gt(pres_p$sd_pp, prior$sd_pp)
  expect_false(any(pres_a$included & pres_a$redist == 1, na.rm = TRUE))
  expect_true(all(is.na(pres_a$redist[pres_a$year == 2018])))
  expect_false(any(pres_a$included & pres_a$year %% 10 == 2))
  used <- pres_a[pres_a$included, ]
  expect_true(all(is.finite(used$d_share_previous) & used$d_share_previous > 0 & used$d_share_previous < 1))
  expect_true(all(used$d_share_current > 0 & used$d_share_current < 1))
  expect_equal(used$d_swing_pp, 100 * (used$d_share_current - used$d_share_previous))
  ak <- used[used$year == 2018 & used$state == "alaska", ]
  expect_equal(ak$d_share_previous, 37.6 / (37.6 + 52.8)) # remove 2016 third-party vote
  dem_year <- used[used$year == 1978, ]
  expect_equal(dem_year$against_president_pp, -dem_year$d_swing_pp)
  expect_lt(pres_h$against_president_pp[pres_h$year == 1978], 0)
  expect_equal(fit_midterm_prior(pres_h, "D")$mean_pp, -pres_p$mean_pp)
})

test_that("presidential replay uses its current-map reference and cumulative totals", {
  for (id in watch_districts) {
    x <- pres_r[pres_r$district_id == id, ]
    expect_true(all(diff(x$d_votes_current) >= 0))
    expect_true(all(diff(x$r_votes_current) >= 0))
  }
  e <- estimate_swing(p, pres_r[pres_r$step == 12, ])
  expect_equal(e$n, 10L)
  expect_equal(e$swing_pp, 3, tolerance = .001)
  wrong <- estimate_swing(b, pres_r[pres_r$step == 12, ])
  expect_gt(abs(wrong$swing_pp - e$swing_pp), .5)
})

test_that("both Bayesian references work and retain their own history and replay", {
  app_env <- new.env(parent = globalenv()); sys.source("app.R", envir = app_env)
  shiny::testServer(app_env$server, {
    session$setInputs(mode="replay", baseline="president", estimator="bayes", step=0,
      min_votes=1000, exclude=character(), prior_scale=1, intro_reference="president", intro_step=0, intro_cycle="2018")
    expect_equal(active_prior()$n_elections, 14L)
    expect_equal(selected_swing(), app_env$pres_prior$mean_pp)
    expect_match(output$intro_reference_note$html, "presidential")
    expect_match(output$intro_history_summary$html, "14 midterms")
    session$setInputs(step=6, intro_step=6)
    expect_equal(estimate()$n, 10L)
    expect_equal(bayesian()$data_se_pp, app_env$pres_prior$district_sd_pp / sqrt(10))
    expect_match(output$intro_replay_summary$html, "73% of the weight")
    expect_equal(bayesian()$mean_pp, app_env$pres_bundle$path$bayes_pp[app_env$pres_bundle$path$step == 6])
    expect_equal(seat_counts(projection()), seat_counts(project_house(app_env$pres_baseline, bayesian()$mean_pp)))
    session$setInputs(baseline="house", intro_reference="house")
    expect_equal(active_prior()$n_elections, 16L)
    expect_equal(bayesian()$mean_pp, app_env$replay_path$bayes_pp[app_env$replay_path$step == 6])
    expect_match(output$intro_history_summary$html, "16 midterms")
    session$setInputs(mode="live", baseline="president")
    expect_true(bayesian()$prior_only)
    expect_equal(selected_swing(), app_env$pres_prior$mean_pp)
  })
})
