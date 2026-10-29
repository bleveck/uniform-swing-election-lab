party_colors <- c(D = "#2165ad", R = "#c65045", Tie = "#989898")
plot_theme <- function() {
  ggplot2::theme_minimal(base_size = 13) + ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
    axis.title = ggplot2::element_text(color = "#556371"), plot.title = ggplot2::element_text(face = "bold"),
    plot.margin = ggplot2::margin(12, 18, 12, 12), text = ggplot2::element_text(family = "sans"))
}

swing_plot <- function(estimate, posterior = NULL) {
  x <- estimate$districts[estimate$districts$district_id %in% watch_districts, ]
  x$district_id <- factor(x$district_id, levels = rev(watch_districts))
  x$direction <- ifelse(x$swing_pp >= 0, "D", "R")
  x$direction[!x$included] <- "Tie"
  p <- ggplot2::ggplot(x, ggplot2::aes(x = swing_pp, y = district_id)) +
    ggplot2::geom_vline(xintercept = 0, color = "#bac4ce") +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = swing_pp, yend = district_id, color = direction), linewidth = 1, na.rm = TRUE) +
    ggplot2::geom_point(ggplot2::aes(color = direction), size = 3.7, na.rm = TRUE) +
    ggplot2::scale_color_manual(values = party_colors, guide = "none") +
    ggplot2::scale_y_discrete(drop = FALSE) +
    ggplot2::labs(x = "Change in D two-party share\n(percentage points)", y = NULL) + plot_theme()
  if (is.finite(estimate$swing_pp)) p <- p + ggplot2::geom_vline(xintercept = estimate$swing_pp, linetype = "dashed", color = "#172f46", linewidth = .8)
  if (!is.null(posterior)) p <- p + ggplot2::geom_vline(xintercept = posterior$mean_pp, color = "#7654a4", linewidth = .9)
  p
}

seats_plot <- function(baseline, swing, posterior = NULL, selected = "Raw") {
  values <- seq(-10, 10, by = .1)
  curve <- data.frame(swing = values, seats = vapply(values, function(s) seat_counts(project_house(baseline, s))[["D"]], integer(1)))
  p <- ggplot2::ggplot(curve, ggplot2::aes(swing, seats)) +
    ggplot2::geom_hline(yintercept = 218, linetype = "dashed", color = "#8996a4") +
    ggplot2::geom_step(color = party_colors[["D"]], linewidth = 1.2) +
    ggplot2::annotate("text", x = -9.7, y = 228, label = "218 for a majority", hjust = 0, color = "#647282", size = 3.4) +
    ggplot2::labs(x = "Uniform change in D two-party share\n(percentage points)", y = "Implied Democratic seats") + plot_theme()
  if (is.finite(swing)) p <- p + ggplot2::geom_vline(xintercept = swing, color = "#172f46", linetype = "dotted") +
    ggplot2::geom_point(data = data.frame(swing = swing, seats = seat_counts(project_house(baseline, swing))[["D"]]), size = if (selected == "Raw") 3.7 else 2.5, color = "#172f46")
  if (!is.null(posterior)) p <- p + ggplot2::geom_vline(xintercept = posterior$mean_pp, color = "#7654a4", linetype = "dashed") +
    ggplot2::geom_point(data = data.frame(swing = posterior$mean_pp, seats = seat_counts(project_house(baseline, posterior$mean_pp))[["D"]]),
      size = if (selected == "Bayesian") 3.7 else 2.5, color = "#7654a4")
  p
}

bayes_density_plot <- function(posterior, raw_pp, x_label = "Democratic two-party share swing (percentage points)") {
  p <- posterior
  means <- c(p$prior_mean_pp, p$mean_pp)
  scales <- c(p$prior_sd_pp, p$sd_pp)
  if (!p$prior_only) { means <- c(means, raw_pp); scales <- c(scales, p$data_se_pp) }
  grid <- seq(min(means - 3.5 * scales), max(means + 3.5 * scales), length.out = 600)
  curves <- rbind(data.frame(swing = grid, density = dnorm(grid, p$prior_mean_pp, p$prior_sd_pp), distribution = "History prior"),
    data.frame(swing = grid, density = dnorm(grid, p$mean_pp, p$sd_pp), distribution = "Posterior"))
  if (!p$prior_only) curves <- rbind(curves, data.frame(swing = grid, density = dnorm(grid, raw_pp, p$data_se_pp), distribution = "Current data likelihood"))
  shaded <- curves[curves$distribution == "Posterior" & curves$swing >= p$lower_pp & curves$swing <= p$upper_pp, ]
  ggplot2::ggplot(curves, ggplot2::aes(swing, density, color = distribution)) +
    ggplot2::geom_area(data = shaded, fill = "#7654a4", alpha = .12, color = NA) +
    ggplot2::geom_line(linewidth = 1, ggplot2::aes(linetype = distribution)) +
    ggplot2::scale_color_manual(values = c("History prior" = "#b97832", "Current data likelihood" = "#657586", "Posterior" = "#7654a4")) +
    ggplot2::scale_linetype_manual(values = c("History prior" = "dashed", "Current data likelihood" = "dotted", "Posterior" = "solid")) +
    ggplot2::labs(x = x_label, y = "Density", color = NULL, linetype = NULL) +
    plot_theme() + ggplot2::theme(legend.position = "bottom")
}

history_prior_plot <- function(history, prior) {
  h <- history[history$included, ]
  mu <- mean(h$against_president_pp)
  ggplot2::ggplot(h, ggplot2::aes(year, against_president_pp, color = president_party)) +
    ggplot2::geom_hline(yintercept = 0, color = "#bac4ce") +
    ggplot2::geom_hline(yintercept = mu, linetype = "dashed", color = "#b97832") +
    ggplot2::geom_point(size = 3.3) +
    ggplot2::scale_color_manual(values = party_colors[c("D", "R")], breaks = c("D", "R"), labels = c("Democratic president", "Republican president"), name = NULL) +
    ggplot2::scale_x_continuous(breaks = seq(1946, 2022, 8)) +
    ggplot2::labs(x = "Midterm year (excluded cycles omitted)", y = "Swing toward the out-party (pp)") +
    plot_theme() + ggplot2::theme(legend.position = "bottom")
}

waffle_plot <- function(projection) {
  x <- projection[order(projection$projected_d_share, decreasing = TRUE), ]
  x$col <- (seq_len(nrow(x)) - 1) %% 29
  x$row <- -((seq_len(nrow(x)) - 1) %/% 29)
  ggplot2::ggplot(x, ggplot2::aes(col, row, fill = projected_party)) +
    ggplot2::geom_tile(width = .85, height = .85) +
    ggplot2::scale_fill_manual(values = party_colors, breaks = c("D", "R", "Tie"),
      labels = c("Democratic", "Republican", "Tied"), name = NULL) +
    ggplot2::coord_fixed() + ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(legend.position = "bottom", plot.margin = ggplot2::margin(5, 0, 0, 0))
}
