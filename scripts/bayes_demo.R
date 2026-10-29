# Analytic Normal-Normal update, using the same functions as Shiny.
source("R/model.R")
source("R/bayes.R")
prior <- fit_midterm_prior(read.csv("data/historical_president_midterms.csv"), president_party = "R")
baseline <- read.csv("data/president_2024_current_map.csv")
replay <- read.csv("data/replay_president.csv")
cat(sprintf("2026 House-minus-president prior: Normal(%+.2f, %.2f^2) pp of Democratic share.\n", prior$mean_pp, prior$sd_pp))
examples <- do.call(rbind, lapply(c(0, 1, 3, 6, 12), function(step) {
  raw <- estimate_swing(baseline, replay[replay$step == step, ])
  post <- normal_swing_update(raw$swing_pp, raw$n, prior)
  data.frame(snapshot = step, districts = raw$n, raw_pp = raw$swing_pp,
    bayes_pp = post$mean_pp, posterior_sd = post$sd_pp, prior_weight = post$prior_weight)
}))
print(examples, row.names = FALSE, digits = 3)
