source("R/historical_returns.R")
ca13_raw <- read.csv("data/ca13_2024_returns.csv", stringsAsFactors = FALSE)
ca13 <- prepare_ca13_returns(ca13_raw, b)

test_that("CA-13 snapshots preserve recorded clocks, totals, and the certified endpoint", {
  expect_equal(nrow(ca13), 31L)
  expect_equal(ca13$recorded_date[c(1, 31)], c("2024-11-05", "2024-12-05"))
  expect_equal(ca13$recorded_time_source[1], "23:46")
  expect_true(all(diff(ca13$source_clock_day) > 0))
  expect_equal(ca13$gray_votes + ca13$duarte_votes, ca13$reported_total)
  expect_equal(tail(ca13$gray_votes, 1), 105554)
  expect_equal(tail(ca13$duarte_votes, 1), 105367)
  expect_equal(tail(ca13$gray_lead, 1), 187)
  expect_equal(tail(ca13$fraction_of_final, 1), 1)
  expect_equal(ca13$fraction_of_final[1], 87063 / 210921)
  expect_equal(ca13$source_time_zone, rep("Not specified", 31))
  # Unchanged archived snapshots stay visible; they are not invented batches.
  expect_true(any(diff(ca13$reported_total) == 0))
})

test_that("recorded leads change from Gray to Duarte and back to Gray", {
  expect_equal(ca13$gray_lead[1:2], c(995, -3189))
  expect_equal(min(ca13$gray_lead), -3765)
  flip <- which(diff(sign(ca13$gray_lead)) != 0) + 1L
  expect_equal(flip, c(2L, 24L))
  expect_equal(ca13$recorded_date[flip], c("2024-11-06", "2024-11-26"))
  expect_equal(ca13$gray_lead[24], 105)
  broken <- ca13_raw; broken$gray_votes[1] <- broken$gray_votes[1] + 1
  expect_error(prepare_ca13_returns(broken, b))
})

test_that("historical replay reveals only recorded snapshots and both views draw", {
  for (step in c(1, 24, 31)) for (metric in c("votes", "share")) {
    plot <- ca13_returns_plot(ca13, step, metric)
    expect_true(all(plot$data$snapshot <= step))
    expect_equal(nrow(plot$data), step)
    expect_no_warning(ggplot2::ggplotGrob(plot))
  }
})

test_that("CA-13 replay controls update without changing the 2026 lab", {
  app_env <- new.env(parent = globalenv()); sys.source("app.R", envir = app_env)
  shiny::testServer(app_env$server, {
    session$setInputs(mode = "replay", baseline = "house", step = 6, min_votes = 1000,
      ca13_step = 1, ca13_metric = "votes")
    expect_match(output$ca13_description$html, "44,029 votes")
    expect_match(output$ca13_cards$html, "Gray \\+995")
    lab_swing <- estimate()$swing_pp
    session$setInputs(ca13_step = 2, ca13_metric = "share")
    expect_match(output$ca13_cards$html, "Duarte \\+3,189")
    session$setInputs(ca13_step = 31)
    expect_match(output$ca13_cards$html, "Gray \\+187")
    expect_match(output$ca13_cards$html, "50.044%")
    expect_equal(estimate()$swing_pp, lab_swing)
  })
})
