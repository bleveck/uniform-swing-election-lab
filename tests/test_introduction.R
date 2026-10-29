source("R/introduction.R")
source("R/plots.R")
districts <- intro_districts(read.csv("data/historical_pair_audit.csv"))

test_that("historical chart pairs preserve the prior sample and all histogram labels", {
  expect_equal(nrow(districts), sum(history$n_districts[history$included]))
  expect_false(anyDuplicated(paste(districts$year, districts$district_id)) > 0)
  for (year in c(2006, 2010, 2014, 2018)) {
    bins <- district_label_bins(districts, year)
    expect_equal(nrow(bins), history$n_districts[history$year == year])
    expect_equal(mean(bins$against_president_pp), history$against_president_pp[history$year == year])
    expect_true(all(bins$against_president_pp >= bins$bin_left & bins$against_president_pp < bins$bin_left + 2))
    expect_equal(sum(tapply(bins$stack, bins$bin_left, max)), nrow(bins))
  }
  expect_true("CA-10" %in% district_label_bins(districts, 2018)$district_id)
  expect_true(any(grepl("-AL$", districts$district_id)))
})

test_that("reporting-order experiment changes early shares while preserving every final vote", {
  paths <- counting_paths()
  for (order in unname(counting_orders)) {
    batches <- counting_batches(order)
    expect_equal(sum(batches$votes), 10000L)
    expect_equal(sum(batches$d_votes), 5500L)
    expect_equal(sum(batches$d_share == .7), 5L)
    expect_equal(paths$d_share_pct[paths$order == order & paths$step == 10], 55)
    expect_true(is.na(paths$d_share_pct[paths$order == order & paths$step == 0]))
  }
  expect_equal(paths$d_share_pct[paths$order == "d_first" & paths$step == 1], 70)
  expect_equal(paths$d_share_pct[paths$order == "r_first" & paths$step == 1], 40)
  expect_equal(paths$d_share_pct[paths$order == "mixed" & paths$step == 2], 55)
})

test_that("intro replay shares the lab calculation and reveals only selected snapshots", {
  path <- intro_replay_path(b, replay, prior)
  expect_true(is.na(path$raw_pp[path$step == 0]))
  expect_equal(path$bayes_pp[path$step == 0], prior$mean_pp)
  for (step in c(1, 6, 12)) {
    raw <- estimate_swing(b, replay[replay$step == step, ])
    post <- normal_swing_update(raw$swing_pp, raw$n, prior)
    expect_equal(path$raw_pp[path$step == step], raw$swing_pp)
    expect_equal(path$bayes_pp[path$step == step], post$mean_pp)
    expect_equal(path$n[path$step == step], raw$n)
  }
  plot <- intro_replay_plot(path, 1, prior$mean_pp)
  expect_true(all(plot$data$step <= 1))
  expect_equal(path$prior_weight[path$step == 6], path$prior_weight[path$step == 12])
})

test_that("intro figures draw with the full sample and at zero returns", {
  path <- intro_replay_path(b, replay, prior)
  figures <- list(uniform_swing_hero(districts), recent_swing_scatter(districts),
    historical_swing_histogram(history), district_label_histogram(district_label_bins(districts, 2018)),
    counting_order_plot(counting_paths(), "r_first", 0), intro_replay_plot(path, 0, prior$mean_pp))
  for (plot in figures) expect_no_warning(ggplot2::ggplotGrob(plot))
})

test_that("introduction controls update counts, signs, and the prior-only state", {
  app_env <- new.env(parent = globalenv()); sys.source("app.R", envir = app_env)
  shiny::testServer(app_env$server, {
    session$setInputs(mode = "replay", baseline = "house", step = 6, min_votes = 1000,
      intro_reference = "house", intro_cycle = "2010", intro_order = "r_first", intro_count = 2, intro_step = 0)
    expect_match(output$intro_bin_summary$html, "2010: 360 districts")
    expect_match(output$intro_bin_summary$html, "Mean \\+7.32 pp toward the out-party")
    expect_match(output$intro_count_summary$html, "40.0% D so far")
    expect_match(output$intro_replay_summary$html, "There is no raw estimate yet")
    session$setInputs(intro_cycle = "2018", intro_order = "d_first", intro_count = 10, intro_step = 6)
    expect_match(output$intro_bin_summary$html, "2018: 317 districts")
    expect_match(output$intro_count_summary$html, "100% counted: 55.0% D")
    expect_match(output$intro_replay_summary$html, "Snapshot 6")
    expect_match(output$intro_replay_summary$html, "48% of the weight")
  })
})
