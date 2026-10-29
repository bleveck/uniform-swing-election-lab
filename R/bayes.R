# Normal empirical prior for a NEW midterm, using between-election spread.
# Each eligible election gets one weight, regardless of its district sample size.
fit_midterm_prior <- function(history, president_party = "R") {
  if (!president_party %in% c("D", "R")) stop("President's party must be D or R.")
  h <- history[history$included, ]
  if (nrow(h) < 2 || any(!is.finite(h$against_president_pp)) || any(h$year < 1946) || any(h$year %% 10 == 2)) stop("Invalid historical midterm sample.")
  mu <- mean(h$against_president_pp)
  tau <- sd(h$against_president_pp) # NOT the standard error of the historical mean
  sigma <- sqrt(sum((h$n_districts - 1) * h$district_sd_pp^2) / sum(h$n_districts - 1))
  if (!is.finite(tau) || tau <= 0 || !is.finite(sigma) || sigma <= 0) stop("Historical variation must be positive.")
  list(mean_pp = if (president_party == "R") mu else -mu, sd_pp = tau,
    district_sd_pp = sigma, n_elections = nrow(h), first_year = min(h$year), last_year = max(h$year),
    president_party = president_party)
}

# District swings are independent conditional on the common mean theta.
# ybar | theta ~ N(theta, sigma_district^2 / n)
# theta ~ N(mu, tau^2). Treat all scales as known for this teaching model.
# No vote-level binomial precision and no reuse of earlier cumulative snapshots.
normal_swing_update <- function(raw_pp, n, prior, prior_sd_multiplier = 1) {
  if (length(n) != 1L || !is.finite(n) || n < 0 || n != floor(n)) stop("n must be a nonnegative district count.")
  scales <- c(prior$sd_pp, prior$district_sd_pp, prior_sd_multiplier)
  if (any(!is.finite(scales) | scales <= 0)) stop("Invalid model scales.")
  mu <- prior$mean_pp
  tau <- prior$sd_pp * prior_sd_multiplier
  if (length(mu) != 1L || !is.finite(mu)) stop("Invalid prior mean.")
  if (n == 0) {
    data_se <- Inf; data_weight <- 0; post_mu <- mu; post_sd <- tau
  } else {
    if (length(raw_pp) != 1L || !is.finite(raw_pp)) stop("An observed mean is required when n > 0.")
    data_se <- prior$district_sd_pp / sqrt(n)
    data_weight <- tau^2 / (tau^2 + data_se^2)
    post_mu <- data_weight * raw_pp + (1 - data_weight) * mu
    post_sd <- sqrt(1 / (1 / tau^2 + 1 / data_se^2))
  }
  list(mean_pp = post_mu, sd_pp = post_sd, prior_mean_pp = mu, prior_sd_pp = tau,
    data_se_pp = data_se, data_weight = data_weight, prior_weight = 1 - data_weight,
    lower_pp = post_mu + qnorm(.025) * post_sd, upper_pp = post_mu + qnorm(.975) * post_sd,
    n = n, prior_only = n == 0)
}
