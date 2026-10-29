prepare_ca13_returns <- function(x, baseline) {
  required <- c("snapshot", "district_id", "election_date", "recorded_date", "recorded_time_source", "gray_votes", "duarte_votes", "reported_total")
  if (!all(required %in% names(x)) || !nrow(x)) stop("Missing CA-13 snapshot fields.")
  stopifnot(all(x$district_id == "CA-13"), all(x$election_date == "2024-11-05"),
    identical(as.integer(x$snapshot), seq_len(nrow(x))))
  for (name in c("gray_votes", "duarte_votes", "reported_total")) {
    stopifnot(all(is.finite(x[[name]]) & x[[name]] >= 0 & x[[name]] == floor(x[[name]])))
  }
  stopifnot(all(x$gray_votes + x$duarte_votes == x$reported_total), all(x$reported_total > 0))
  final <- baseline[baseline$district_id == "CA-13", ]
  stopifnot(nrow(final) == 1L, tail(x$gray_votes, 1) == final$d_votes, tail(x$duarte_votes, 1) == final$r_votes)
  # Preserve the sheet's clock without assigning an undocumented time zone.
  day <- as.numeric(as.Date(x$recorded_date) - as.Date("2024-11-05"))
  hour <- as.numeric(substr(x$recorded_time_source, 1, 2))
  minute <- as.numeric(substr(x$recorded_time_source, 4, 5))
  stopifnot(all(is.finite(day)), all(hour >= 0 & hour < 24), all(minute >= 0 & minute < 60))
  x$source_clock_day <- day + hour / 24 + minute / 1440
  stopifnot(all(diff(x$source_clock_day) > 0))
  x$gray_lead <- x$gray_votes - x$duarte_votes
  x$gray_share_pct <- 100 * x$gray_votes / x$reported_total
  x$fraction_of_final <- x$reported_total / (final$d_votes + final$r_votes)
  x$leader <- ifelse(x$gray_lead > 0, "D", ifelse(x$gray_lead < 0, "R", "Tie"))
  x
}

ca13_returns_plot <- function(snapshots, step, metric = "votes") {
  stopifnot(metric %in% c("votes", "share"), step %in% snapshots$snapshot)
  x <- snapshots[snapshots$snapshot <= step, ]
  x$value <- if (metric == "votes") x$gray_lead else x$gray_share_pct
  all_values <- if (metric == "votes") snapshots$gray_lead else snapshots$gray_share_pct
  reference <- if (metric == "votes") 0 else 50
  limits <- range(c(all_values, reference))
  pad <- diff(limits) * .15
  p <- ggplot2::ggplot(x, ggplot2::aes(source_clock_day, value)) +
    ggplot2::geom_hline(yintercept = reference, color = "#8493a0", linewidth = .8) +
    ggplot2::geom_point(ggplot2::aes(color = leader), size = 2.5) +
    ggplot2::scale_color_manual(values = party_colors, breaks = c("D", "R"),
      labels = c("Gray leads (D)", "Duarte leads (R)"), name = NULL) +
    ggplot2::scale_x_continuous(limits = c(0, ceiling(max(snapshots$source_clock_day))), breaks = c(0, 7, 14, 21, 28, 30),
      labels = function(v) format(as.Date("2024-11-05") + v, "%b %d")) +
    ggplot2::scale_y_continuous(limits = limits + c(-pad, pad),
      labels = if (metric == "votes") function(v) format(v, big.mark = ",", scientific = FALSE, trim = TRUE) else function(v) sprintf("%.1f%%", v)) +
    ggplot2::labs(x = "CVF snapshot date (2024; source clock)",
      y = if (metric == "votes") "Gray votes − Duarte votes" else "Gray’s Democratic two-party share") +
    plot_theme() + ggplot2::theme(legend.position = "bottom")
  # Steps show the last recorded value, without interpolating missing updates.
  if (nrow(x) > 1) p <- p + ggplot2::geom_step(color = "#344e65", linewidth = .8)
  p + ggplot2::geom_point(data = tail(x, 1), ggplot2::aes(fill = leader),
    shape = 21, color = "#7654a4", stroke = 1.2, size = 4, show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = party_colors, guide = "none")
}

ca13_history_ui <- function(snapshots) {
  panel("Close to home: CA-13’s real 2024 count", "RECORDED HISTORICAL RETURNS · Adam Gray (D) and John Duarte (R). The California Voter Foundation preserved 31 snapshots from November 5 through December 5.",
    tags$p("The recorded lead changed hands twice: Gray led in the first election-night snapshot, Duarte led the next morning, and Gray was back ahead in the November 26 snapshots. The certified result was Gray by 187 votes."),
    tags$div(class = "story-controls",
      sliderInput("ca13_step", "Recorded snapshot", min = 1, max = nrow(snapshots), value = nrow(snapshots), step = 1,
        animate = animationOptions(interval = 1700, loop = FALSE)),
      radioButtons("ca13_metric", "Plot the count as", choices = c("Vote lead: Gray − Duarte" = "votes", "Democratic vote share" = "share"), selected = "votes", inline = TRUE)),
    tags$p(class = "small-note", "Drag the slider left to return to election night, then press play to reveal the count. Dates are irregular: these are archived observations, including unchanged totals, rather than every update."),
    tags$div(class = "metric-grid story-metrics", uiOutput("ca13_cards")),
    uiOutput("ca13_description"), plotOutput("ca13_plot", height = "390px"),
    tags$p(class = "small-note", "Points mark CVF’s recorded totals; steps hold the last recorded value between snapshots. Blue = Gray leads; red = Duarte leads. The purple ring marks the selected snapshot."),
    tags$details(class = "story-source", tags$summary("Sources, recorded times, and what “counted” means"),
      tags$p("CVF transcribed unofficial California Secretary of State results. The recording times are preserved exactly as printed in the workbook; its time zone is not specified. They are observation times, not timestamps of every county update. Missing intermediate updates are not reconstructed."),
      tags$p("The percentage of final votes is calculated retrospectively from the certified 210,921 D+R votes. It was not a contemporaneous estimate of the percentage counted. The workbook’s unprocessed-ballot figures cover whole counties, so they are not used as a CA-13 denominator."),
      tags$p("The last snapshot matches the official result: Gray 105,554; Duarte 105,367. This historical example illustrates the count separately from the 2026 swing model."),
      tags$p(tags$a(href = "https://www.calvoter.org/content/close-count-transparency-project", "California Voter Foundation: project and methodology"), " · ",
        tags$a(href = "https://docs.google.com/spreadsheets/d/1_sHIMjAD-bbgn7MsKLb9_U3bJQyB6FVq/edit", "Original tracking workbook (CD-13 tab)"), " · ",
        tags$a(href = "https://elections.cdn.sos.ca.gov/sov/2024-general/sov/06-sov-summary.pdf", "California Secretary of State: certified results")),
      lab_download_button("ca13_download", "Download the recorded CA-13 snapshots")))
}

ca13_history_server <- function(input, output, snapshots) {
  selected <- shiny::reactive(input$ca13_step %||% nrow(snapshots))
  current <- shiny::reactive(snapshots[snapshots$snapshot == selected(), ])
  output$ca13_cards <- shiny::renderUI({
    x <- current()
    card <- function(label, value, detail) tags$div(class = "metric", tags$div(class = "metric-label", label),
      tags$div(class = "metric-value", value), tags$div(class = "metric-detail", detail))
    leader <- if (x$gray_lead > 0) "Gray" else if (x$gray_lead < 0) "Duarte" else "Tied"
    shiny::tagList(card("LEAD IN THIS SNAPSHOT", sprintf("%s +%s", leader, format(abs(x$gray_lead), big.mark = ",")), "Votes separating the candidates"),
      card("DEMOCRATIC SHARE", sprintf("%.3f%%", x$gray_share_pct), "Gray votes ÷ (Gray + Duarte votes)"),
      card("VOTES IN THIS SNAPSHOT", format(x$reported_total, big.mark = ","), sprintf("%.1f%% of the final D+R total (known afterward)", 100 * x$fraction_of_final)))
  })
  output$ca13_description <- shiny::renderUI({
    x <- current()
    tags$p(class = "bin-summary", sprintf("Snapshot %d of %d · %s at %s (CVF’s source clock). Gray: %s votes; Duarte: %s votes.",
      x$snapshot, nrow(snapshots), format(as.Date(x$recorded_date), "%B %d, %Y"), x$recorded_time_source,
      format(x$gray_votes, big.mark = ","), format(x$duarte_votes, big.mark = ",")))
  })
  output$ca13_plot <- shiny::renderPlot(ca13_returns_plot(snapshots, selected(), input$ca13_metric %||% "votes"), res = 110)
  output$ca13_download <- lab_download_handler(filename = "CA-13_2024_recorded_returns.csv", content = function(file) {
    utils::write.csv(snapshots[, !names(snapshots) %in% c("source_clock_day", "leader")], file, row.names = FALSE)
  })
}
