# Historical charts use exactly the matched, contested pairs in the prior audit.
intro_districts <- function(audit) {
  x <- audit[audit$included, , drop = FALSE]
  abbreviation <- state.abb[match(x$state, tolower(state.name))]
  stopifnot(!anyNA(abbreviation))
  x$district_id <- paste0(abbreviation, "-", ifelse(x$district == 0, "AL", sprintf("%02d", x$district)))
  stopifnot(!anyDuplicated(paste(x$year, x$district_id)))
  x
}

district_label_bins <- function(districts, year, bin_width = 2) {
  x <- districts[districts$year == year, , drop = FALSE]
  stopifnot(nrow(x) > 0, is.finite(bin_width), bin_width > 0)
  # Half-open bins [left, right); every district, including outliers, stays in.
  x$bin_left <- bin_width * floor(x$against_president_pp / bin_width)
  x$bin_center <- x$bin_left + bin_width / 2
  x <- x[order(x$bin_left, x$district_id), ]
  x$stack <- ave(seq_len(nrow(x)), x$bin_left, FUN = seq_along)
  x
}

# A controlled reporting-order example: ten equal batches, fixed final votes.
# The groups are invented and imply no rule about real precincts or vote modes.
counting_orders <- c("D-leaning batches first" = "d_first", "R-leaning batches first" = "r_first", "Alternating batches" = "mixed")
counting_batches <- function(order = "d_first") {
  stopifnot(order %in% unname(counting_orders))
  shares <- switch(order, d_first = c(rep(.7, 5), rep(.4, 5)),
    r_first = c(rep(.4, 5), rep(.7, 5)), mixed = rep(c(.7, .4), 5))
  data.frame(batch = 1:10, votes = 1000L, d_votes = as.integer(1000 * shares),
    d_share = shares, group = ifelse(shares == .7, "70% D", "40% D"))
}

counting_paths <- function() {
  do.call(rbind, lapply(unname(counting_orders), function(order) {
    b <- counting_batches(order)
    data.frame(order = order, step = 0:10, counted_pct = 10 * (0:10),
      d_share_pct = c(NA_real_, 100 * cumsum(b$d_votes) / cumsum(b$votes)))
  }))
}

intro_replay_path <- function(baseline, replay, prior) {
  do.call(rbind, lapply(sort(unique(replay$step)), function(step) {
    raw <- estimate_swing(baseline[baseline$district_id %in% watch_districts, ], replay[replay$step == step, ])
    post <- normal_swing_update(raw$swing_pp, raw$n, prior)
    seats <- seat_counts(project_house(baseline, post$mean_pp))
    data.frame(step = step, n = raw$n, raw_pp = raw$swing_pp, bayes_pp = post$mean_pp,
      prior_weight = post$prior_weight, posterior_sd = post$sd_pp,
      d_seats = seats[["D"]], r_seats = seats[["R"]])
  }))
}

uniform_swing_hero <- function(districts, year = 2010, reference = "house") {
  x <- districts[districts$year == year, ]
  delta <- mean(x$d_swing_pp)
  example <- x[x$district_id == "FL-22", ]
  ggplot2::ggplot(x, ggplot2::aes(100 * d_share_previous, 100 * d_share_current)) +
    ggplot2::geom_hline(yintercept = 50, color = "#e8edf1") +
    ggplot2::geom_vline(xintercept = 50, color = "#e8edf1") +
    ggplot2::geom_abline(slope = 1, intercept = 0, color = "#8493a0", linetype = "dashed", linewidth = .8) +
    ggplot2::geom_abline(slope = 1, intercept = delta, color = party_colors[["R"]], linewidth = 1.1) +
    ggplot2::geom_point(color = "#344e65", alpha = .5, size = 1.9) +
    ggplot2::geom_point(data = example, color = "#7654a4", size = 3.7) +
    ggplot2::annotate("segment", x = 32, xend = 32, y = 32, yend = 32 + delta,
      arrow = grid::arrow(length = grid::unit(.09, "inches"), ends = "both"), color = party_colors[["R"]], linewidth = .8) +
    ggplot2::annotate("label", x = 6, y = 16, hjust = 0, label = sprintf("Mean shift\n%+.1f pp D share", delta),
      color = party_colors[["R"]], fill = "white", linewidth = 0, size = 3.4) +
    ggplot2::annotate("segment", x = 69, xend = 100 * example$d_share_previous + 1.5,
      y = 30, yend = 100 * example$d_share_current - 1.5, color = "#7654a4") +
    ggplot2::annotate("label", x = 70, y = 25, hjust = 0, label = "FL-22\nCrosses the 50% line", color = "#7654a4", linewidth = 0, size = 3.1) +
    ggplot2::annotate("label", x = 55, y = 90, label = "Dashed: no change (y = x)", color = "#657586", linewidth = 0, size = 3.1) +
    ggplot2::annotate("label", x = 63, y = 8, label = sprintf("Red: uniform shift (y = x %.2f)", delta),
      color = party_colors[["R"]], linewidth = 0, size = 3.1) +
    ggplot2::scale_x_continuous(breaks = seq(0, 100, 20), labels = function(v) paste0(v, "%")) +
    ggplot2::scale_y_continuous(breaks = seq(0, 100, 20), labels = function(v) paste0(v, "%")) +
    ggplot2::coord_fixed(xlim = c(0, 100), ylim = c(0, 100), expand = FALSE) +
    ggplot2::labs(x = sprintf("%d Democratic two-party %s share", year - 2, if (reference == "president") "presidential" else "House"), y = sprintf("%d Democratic two-party House share", year)) + plot_theme()
}

recent_swing_scatter <- function(districts, reference = "house") {
  x <- districts[districts$year %in% c(2006, 2010, 2014, 2018), ]
  means <- aggregate(d_swing_pp ~ year, x, mean)
  means$n <- as.integer(table(factor(x$year, levels = means$year)))
  means$cycle <- sprintf("%d %s → %d House\nD %+.1f pp · %d districts", means$year - 2, if (reference == "president") "president" else "House", means$year, means$d_swing_pp, means$n)
  x$cycle <- factor(means$cycle[match(x$year, means$year)], levels = means$cycle)
  means$cycle <- factor(means$cycle, levels = means$cycle)
  means$direction <- ifelse(means$d_swing_pp > 0, "D", "R")
  ggplot2::ggplot(x, ggplot2::aes(100 * d_share_previous, 100 * d_share_current)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, color = "#8493a0", linetype = "dashed") +
    ggplot2::geom_abline(data = means, ggplot2::aes(slope = 1, intercept = d_swing_pp, color = direction), linewidth = .9) +
    ggplot2::geom_point(color = "#344e65", alpha = .45, size = 1.2) +
    ggplot2::scale_color_manual(values = party_colors, guide = "none") +
    ggplot2::facet_wrap(~cycle, ncol = 2) +
    ggplot2::scale_x_continuous(breaks = c(0, 50, 100), labels = function(v) paste0(v, "%")) +
    ggplot2::scale_y_continuous(breaks = c(0, 50, 100), labels = function(v) paste0(v, "%")) +
    ggplot2::coord_fixed(xlim = c(0, 100), ylim = c(0, 100), expand = FALSE) +
    ggplot2::labs(x = if (reference == "president") "Previous Democratic two-party presidential share" else "Previous Democratic two-party House share", y = "Midterm Democratic two-party House share") +
    plot_theme() + ggplot2::theme(strip.text = ggplot2::element_text(face = "bold", size = 10))
}

historical_swing_histogram <- function(history) {
  h <- history[history$included, ]
  ggplot2::ggplot(h, ggplot2::aes(against_president_pp)) +
    ggplot2::geom_histogram(binwidth = 2, boundary = 0, closed = "left", fill = "#d8b386", color = "white", linewidth = .8) +
    ggplot2::geom_vline(xintercept = 0, color = "#8493a0") +
    ggplot2::geom_vline(xintercept = mean(h$against_president_pp), color = "#b97832", linetype = "dashed", linewidth = .9) +
    ggplot2::scale_x_continuous(breaks = seq(2 * floor(min(h$against_president_pp) / 2), 2 * ceiling(max(h$against_president_pp) / 2), by = 2)) +
    ggplot2::scale_y_continuous(breaks = scales::breaks_width(1), expand = ggplot2::expansion(mult = c(0, .1))) +
    ggplot2::labs(x = "Mean performance toward the out-party (pp)", y = "Number of midterms") + plot_theme()
}

district_label_histogram <- function(bins, highlight = "CA-10") {
  avg <- mean(bins$against_president_pp)
  bins$highlight <- bins$district_id == highlight
  ggplot2::ggplot(bins, ggplot2::aes(bin_center, stack)) +
    ggplot2::geom_vline(xintercept = 0, color = "#8493a0") +
    ggplot2::geom_vline(xintercept = avg, color = "#b97832", linetype = "dashed", linewidth = .8) +
    ggplot2::geom_tile(data = bins[bins$highlight, ], fill = "#e7def5", width = 1.9, height = .95) +
    ggplot2::geom_text(ggplot2::aes(label = district_id, color = highlight, fontface = ifelse(highlight, "bold", "plain")),
      family = "mono", size = 3) +
    ggplot2::scale_color_manual(values = c("FALSE" = "#344e65", "TRUE" = "#7654a4"), guide = "none") +
    ggplot2::scale_x_continuous(breaks = seq(2 * floor(min(bins$bin_left) / 2), max(bins$bin_left) + 2, by = 4),
      expand = ggplot2::expansion(add = 1.2)) +
    ggplot2::scale_y_continuous(breaks = seq(0, max(bins$stack) + 5, by = 10), limits = c(0, max(bins$stack) + 1),
      expand = ggplot2::expansion(mult = c(0, .01))) +
    ggplot2::labs(x = "District performance toward the out-party (percentage points; 2 pp bins)", y = "Districts stacked in each bin") + plot_theme()
}

counting_order_plot <- function(paths, order, step) {
  selected <- paths[paths$order == order & paths$step > 0, ]
  now <- selected[selected$step == step, ]
  ggplot2::ggplot(paths[paths$step > 0, ], ggplot2::aes(counted_pct, d_share_pct, group = order)) +
    ggplot2::geom_hline(yintercept = 52, color = "#8493a0", linetype = "dotted") +
    ggplot2::geom_hline(yintercept = 55, color = "#b97832", linetype = "dashed") +
    ggplot2::geom_line(color = "#cbd5de", linewidth = .9) +
    ggplot2::geom_line(data = selected, color = "#7654a4", linewidth = 1.4) +
    ggplot2::geom_point(data = now, color = "#7654a4", size = 4) +
    ggplot2::geom_vline(xintercept = step * 10, color = "#7654a4", alpha = .3) +
    ggplot2::annotate("label", x = 2, y = 56.7, hjust = 0, label = "Final: 55% D", color = "#9b642b", linewidth = 0, size = 3.2) +
    ggplot2::annotate("label", x = 2, y = 50.3, hjust = 0, label = "Previous election: 52% D", color = "#657586", linewidth = 0, size = 3.2) +
    ggplot2::scale_x_continuous(breaks = seq(0, 100, 20), limits = c(0, 100), labels = function(v) paste0(v, "%")) +
    ggplot2::scale_y_continuous(breaks = seq(40, 70, 10), limits = c(37, 74), labels = function(v) paste0(v, "%")) +
    ggplot2::labs(x = "Share of this toy election’s final ballots counted", y = "Cumulative Democratic two-party share") + plot_theme()
}

intro_replay_plot <- function(path, step, prior_mean, reference = "house") {
  x <- path[path$step <= step, ]
  curves <- rbind(data.frame(step = x$step, swing = x$raw_pp, method = "Raw district average"),
    data.frame(step = x$step, swing = x$bayes_pp, method = "History + results"))
  line_curves <- curves[is.finite(curves$swing) & ave(is.finite(curves$swing), curves$method, FUN = sum) >= 2, ]
  ggplot2::ggplot(curves, ggplot2::aes(step, swing, color = method)) +
    ggplot2::geom_hline(yintercept = prior_mean, color = "#b97832", linetype = "dashed") +
    ggplot2::geom_line(data = line_curves, linewidth = 1, na.rm = TRUE) +
    ggplot2::geom_point(size = 3, na.rm = TRUE) +
    ggplot2::scale_color_manual(values = c("Raw district average" = "#344e65", "History + results" = "#7654a4"), name = NULL) +
    ggplot2::scale_x_continuous(limits = c(0, 12), breaks = c(0, 1, 3, 6, 9, 12)) +
    ggplot2::scale_y_continuous(limits = range(c(path$raw_pp, path$bayes_pp, prior_mean), na.rm = TRUE) + c(-.6, .6)) +
    ggplot2::labs(x = "Synthetic cumulative snapshot", y = if (reference == "president") "House − presidential D share (pp)" else "Estimated Democratic share swing (pp)") +
    plot_theme() + ggplot2::theme(legend.position = "bottom")
}

introduction_ui <- function(ca13_returns) {
  story_heading <- function(n, title, text) tags$div(class = "story-heading",
    tags$span(class = "story-number", n), tags$div(tags$h2(title), tags$p(text)))
  tags$main(class = "introduction",
    tags$div(class = "story-lede",
      tags$p("You wake up on election night. You have missed the polls, the campaigns, and every prediction. What can a political scientist still bring to the first returns?"),
      tags$p("Start with district partisanship, a common national swing, and the history of midterms. Then watch what happens when the votes begin to arrive.")),
    tags$div(class = "panel-card story-reference",
      selectInput("intro_reference", "Reference vote for this introduction", c("Previous presidential election" = "president", "Previous House election" = "house"), selected = "president"),
      uiOutput("intro_reference_note")),
    tags$nav(class = "story-nav", `aria-label` = "Introduction sections",
      tags$a(href = "#common-swing", "1 · A common swing"), tags$a(href = "#midterm-history", "2 · History and local variation"),
      tags$a(href = "#incomplete-returns", "3 · An unfinished count"), tags$a(href = "#waking-up", "4 · Interpret the first results")),
    tags$section(id = "common-swing", class = "story-section",
      story_heading("01", "Different districts. A common direction.", "Districts keep much of their relative partisanship, even as an election shifts the country’s political balance."),
      tags$div(class = "panel-card story-hero-grid",
        tags$div(class = "hero-copy", tags$div(class = "eyebrow", "A CLOSER LOOK · 2008 → 2010"),
          tags$h3("A Republican wave, drawn one district at a time."), uiOutput("intro_hero_summary"),
          tags$p("On the dashed diagonal, the midterm House candidate earns the same Democratic share as the selected reference vote. A uniform shift moves that line vertically while keeping its slope at one."),
          tags$p("The red line applies the same average shift to every district. The cloud around it shows where individual races depart from that simple rule."),
          tags$p(class = "small-note", "Each point is a matched district contested by both major parties in both elections. All values are two-party vote shares.")),
        plotOutput("intro_hero", height = "520px")),
      panel("The pattern across four midterms", "Dashed gray: y = x. Colored line: y = x + that election’s mean Democratic-share swing. Both axes run from 0% to 100%.",
        plotOutput("intro_scatter", height = "650px"),
        tags$p(class = "small-note", "These are the four most recent eligible midterms in the bundled history. The 2022 post-census cycle is excluded. Changed-map states and unpaired or one-party contests are excluded within each plotted cycle."))),
    tags$section(id = "midterm-history", class = "story-section",
      story_heading("02", "History gives us a starting point. Districts give us variation.", "Separate variation between elections from variation among districts within the same election."),
      tags$div(class = "chart-grid story-history-grid",
        panel("One dot = one midterm", "Positive always means movement toward the out-party, regardless of which party holds the presidency.", plotOutput("intro_history_time", height = "330px")),
        panel("One bar counts midterms", "The same election averages, grouped into 2 pp bins. The dashed line is their mean.", plotOutput("intro_history_hist", height = "330px"))),
      tags$div(class = "story-takeaway", uiOutput("intro_history_summary")),
      panel("One label = one congressional district", "Within a single cycle, districts scatter around the common swing. Every retained district occupies one place in its bin; taller stacks contain more districts.",
        tags$div(class = "story-controls",
          selectInput("intro_cycle", "Choose a midterm", choices = c("2006", "2010", "2014", "2018"), selected = "2018"),
          selectizeInput("intro_highlight", "Find a retained district", choices = NULL, options = list(placeholder = "Type a district, e.g. CA-10"))),
        uiOutput("intro_bin_summary"),
        tags$p(class = "small-note scroll-hint", "Scroll horizontally on smaller screens to read the district labels. Zero = no change; dashed amber = this cycle’s district average."),
        tags$div(class = "district-label-scroll", uiOutput("intro_district_plot_ui")),
        tags$p(class = "small-note", "This chart measures swing toward the out-party. In 2010 and 2014 that means Republican gains; in 2006 and 2018 it means Democratic gains. Negative values mean a district moved toward the president’s party.")),
      tags$details(class = "story-source", tags$summary("Historical sample and sources"),
        uiOutput("intro_history_source_note"),
        tags$p("Returns: ", tags$a(href = "https://doi.org/10.17605/OSF.IO/MJVKB", "Wolf / King / CLEA"), " and ",
          tags$a(href = "https://github.com/MEDSL/constituency-returns", "MIT Election Lab"), ". Boundary screen: ",
          tags$a(href = "https://github.com/JeffreyBLewis/congressional-district-boundaries", "Lewis et al."), ". Presidential-reference data: ",
          tags$a(href = "https://doi.org/10.7910/DVN/29559", "Gary Jacobson"), " and ",
          tags$a(href = "https://www.shirokuriwaki.com/ccesMRPprep/reference/cd_info.html", "The Downballot / ccesMRPprep"), "."),
        downloadButton("intro_history_download", "Download the plotted district pairs"))),
    tags$section(id = "incomplete-returns", class = "story-section",
      story_heading("03", "An unfinished count can tell different stories.", "Change the reporting order while holding every vote fixed."),
      panel("Same electorate. Same final result. Different first impressions.", "CONTROLLED TOY EXAMPLE · Ten batches of 1,000 votes: five are 70% D, five are 40% D. The final result is always 55% D, up from 52% in the previous election.",
        tags$div(class = "story-controls",
          radioButtons("intro_order", "Which batches arrive first?", choices = counting_orders, selected = "d_first", inline = TRUE),
          sliderInput("intro_count", "Batches counted", min = 0, max = 10, value = 2, step = 1)),
        uiOutput("intro_batches"), uiOutput("intro_count_summary"),
        plotOutput("intro_count_plot", height = "370px"),
        tags$p(class = "small-note", "Purple is the selected order; pale lines show the alternatives. The full paths and final result are visible because this is a controlled example. On election night, the eventual ballot total and final vote share are unknown.")),
      tags$div(class = "story-takeaway", tags$p("A change in the reported share can come from which ballots arrived next. More votes in the same district update that district’s result; they do not add another independent district to our swing estimate.")),
      ca13_history_ui(ca13_returns)),
    tags$section(id = "waking-up", class = "story-section",
      story_heading("04", "Now wake up and read the first returns.", "Combine what history taught you with what tonight’s districts are telling you."),
      panel("How much should the first result change your mind?", "SYNTHETIC 2026 REPLAY · Invented cumulative House returns on the selected reference map. The raw average and the historical-prior update use the same included districts.",
        sliderInput("intro_step", "Reveal a snapshot", min = 0, max = 12, value = 1, step = 1,
          animate = animationOptions(interval = 1800, loop = FALSE)),
        tags$div(class = "metric-grid story-metrics", uiOutput("intro_replay_cards")),
        uiOutput("intro_replay_summary"), plotOutput("intro_replay_plot", height = "350px"),
        tags$p(class = "small-note", "Dashed amber = the historical prior mean. The update assumes independent district deviations conditional on a common swing, with historical residual variance divided by the district count. Cumulative snapshots replace earlier ones. The prior’s fitted parameters stay fixed in this introduction."),
        actionButton("intro_open_lab", "Continue with this snapshot in the election-night lab →", class = "btn-primary",
          onclick = "Shiny.setInputValue('intro_step', Number(document.getElementById('intro_step').value), {priority: 'event'});")),
      tags$p(class = "story-closing", "The question to carry into the lab: what have these returns taught you beyond what you knew when you woke up?")))
}

introduction_server <- function(input, output, session, districts, history, prior, replay_path, ca13_returns, presidential) {
  ca13_history_server(input, output, ca13_returns)
  datasets <- list(house = list(districts = districts, history = history, prior = prior, path = replay_path), president = presidential)
  reference <- shiny::reactive(input$intro_reference %||% "president")
  chosen <- shiny::reactive(datasets[[reference()]])
  cycle <- shiny::reactive(as.integer(input$intro_cycle %||% 2018))
  bins <- shiny::reactive(district_label_bins(chosen()$districts, cycle()))
  order <- shiny::reactive(input$intro_order %||% "d_first")
  count <- shiny::reactive(input$intro_count %||% 2)
  step <- shiny::reactive(input$intro_step %||% 1)
  current <- shiny::reactive({path <- chosen()$path; path[path$step == step(), ]})
  paths <- counting_paths()
  shiny::observeEvent(list(cycle(), reference()), {
    ids <- sort(bins()$district_id)
    previous <- shiny::isolate(input$intro_highlight)
    selected <- if (!is.null(previous) && previous %in% ids) previous else if ("CA-10" %in% ids) "CA-10" else ids[1]
    shiny::updateSelectizeInput(session, "intro_highlight", choices = ids, selected = selected, server = TRUE)
  })
  output$intro_reference_note <- shiny::renderUI(tags$p(class = "small-note", if (reference() == "president")
    "Default: compare midterm House vote share with the preceding presidential vote. Positive D performance means the House candidate runs ahead of the Democratic presidential share. For 2026, the presidential reference is Harris’s 2024 vote on 2026 district lines. A separate historical prior is fitted to this cross-office difference." else
    "Compare midterm House vote share with the preceding House election. This uses the original map and a separately fitted House-to-House prior; changed-map states remain excluded from live House comparisons."))
  output$intro_hero <- shiny::renderPlot(uniform_swing_hero(chosen()$districts, reference = reference()), res = 110)
  output$intro_hero_summary <- shiny::renderUI({
    d <- chosen()$districts; x <- d[d$year == 2010, ]
    shiny::tagList(shiny::tags$div(class = "hero-stat", sprintf("%.1f pp", -mean(x$d_swing_pp))),
      shiny::tags$p(class = "hero-stat-label", sprintf("Average Republican gain relative to the reference across %d retained districts.", nrow(x))))
  })
  output$intro_scatter <- shiny::renderPlot(recent_swing_scatter(chosen()$districts, reference()), res = 110)
  output$intro_history_time <- shiny::renderPlot(history_prior_plot(chosen()$history, chosen()$prior), res = 110)
  output$intro_history_hist <- shiny::renderPlot(historical_swing_histogram(chosen()$history), res = 110)
  output$intro_history_summary <- shiny::renderUI({ p <- chosen()$prior; shiny::tags$p(sprintf(
    "Across these %d midterms, mean performance toward the out-party relative to this reference is %+.1f pp, with a between-election SD of %.2f pp. That spread supplies the Normal prior for a new midterm. The next chart asks a different question: how much do districts vary within one election?",
    p$n_elections, p$mean_pp, p$sd_pp)) })
  output$intro_history_source_note <- shiny::renderUI({ p <- chosen()$prior; tags$p(sprintf(
    "These panels use %d eligible midterms from %d through %d. Post-census midterms 1962, 1982, 2002, and 2022 are excluded. Each election supplies one equal-weight district mean. %s",
    p$n_elections, p$first_year, p$last_year, if (reference() == "president") "Jacobson’s redrawn-district flag and missing or unopposed House races are screened out. Presidential district shares are unavailable for 1946 and 1950. The 2018 extension pairs 2018 House shares with 2016 presidential shares explicitly aggregated to 2018 lines." else "The House-to-House audit screens changed-map states, ambiguous matches, and contests without both major parties in both elections.")) })
  label_height <- shiny::reactive(max(700, 100 + 15 * max(bins()$stack)))
  output$intro_district_plot_ui <- shiny::renderUI(shiny::plotOutput("intro_district_hist", width = "1250px", height = paste0(label_height(), "px")))
  output$intro_district_hist <- shiny::renderPlot(district_label_histogram(bins(), input$intro_highlight %||% "CA-10"), width = 1250, height = function() label_height(), res = 110)
  output$intro_bin_summary <- shiny::renderUI({
    x <- bins(); selected <- x[x$district_id == (input$intro_highlight %||% "CA-10"), ]
    shiny::tags$p(class = "bin-summary", sprintf("%d: %d districts · Mean %+.2f pp toward the out-party · District SD %.2f pp.", cycle(), nrow(x), mean(x$against_president_pp), sd(x$against_president_pp)),
      if (nrow(selected)) sprintf(" Highlighted %s: %+.2f pp, in [%+.0f, %+.0f) pp.", selected$district_id, selected$against_president_pp, selected$bin_left, selected$bin_left + 2))
  })
  output$intro_batches <- shiny::renderUI({
    b <- counting_batches(order())
    shiny::tags$div(class = "batch-strip", `aria-label` = "Reporting order of ten equal vote batches", lapply(seq_len(nrow(b)), function(i)
      shiny::tags$div(class = paste("batch", if (b$d_share[i] == .7) "batch-d" else "batch-r", if (i > count()) "batch-waiting" else "batch-counted"),
        shiny::tags$span(paste("Batch", i)), shiny::tags$strong(b$group[i]), shiny::tags$span(if (i <= count()) "Counted" else "Waiting"))))
  })
  output$intro_count_summary <- shiny::renderUI({
    if (count() == 0) return(shiny::tags$p(class = "bin-summary", "No ballots counted yet. All three reporting orders will finish at 55% D."))
    x <- paths[paths$order == order() & paths$step == count(), ]
    shiny::tags$p(class = "bin-summary", sprintf("%d%% counted: %.1f%% D so far, an apparent %+.1f pp swing. The completed count will be 55.0%% D, a +3.0 pp swing.", x$counted_pct, x$d_share_pct, x$d_share_pct - 52))
  })
  output$intro_count_plot <- shiny::renderPlot(counting_order_plot(paths, order(), count()), res = 110)
  output$intro_replay_cards <- shiny::renderUI({
    x <- current()
    card <- function(label, value, detail) shiny::tags$div(class = "metric", shiny::tags$div(class = "metric-label", label),
      shiny::tags$div(class = "metric-value", value), shiny::tags$div(class = "metric-detail", detail))
    shiny::tagList(card("RAW DISTRICT AVERAGE", fmt_pp(x$raw_pp), sprintf("%d included district%s", x$n, if (x$n == 1) "" else "s")),
      card("HISTORY + RESULTS", fmt_pp(x$bayes_pp), sprintf("%.0f%% history + %.0f%% current data", 100 * x$prior_weight, 100 * (1 - x$prior_weight))),
      card("BAYESIAN IMPLIED HOUSE", sprintf("D %d / R %d", x$d_seats, x$r_seats), if (reference() == "president") "Presidential reference on the 2026 map" else "Uniform shift on the 2024 map"))
  })
  output$intro_replay_summary <- shiny::renderUI({
    x <- current()
    p <- chosen()$prior
    text <- if (x$n == 0) sprintf("Before returns, history supplies the entire estimate: %+.2f pp D share relative to the selected reference. There is no raw estimate yet.", p$mean_pp) else
      sprintf("Snapshot %d: the raw district average is %+.2f pp. Combining it with the historical expectation of %+.2f pp gives %+.2f pp. The current districts receive %.0f%% of the weight.", x$step, x$raw_pp, p$mean_pp, x$bayes_pp, 100 * (1 - x$prior_weight))
    shiny::tags$p(class = "bin-summary", text)
  })
  output$intro_replay_plot <- shiny::renderPlot(intro_replay_plot(chosen()$path, step(), chosen()$prior$mean_pp, reference()), res = 110)
  output$intro_history_download <- shiny::downloadHandler(filename = "historical_plotted_district_pairs.csv", content = function(file) utils::write.csv(chosen()$districts, file, row.names = FALSE))
  shiny::observeEvent(input$intro_open_lab, {
    shiny::updateRadioButtons(session, "mode", selected = "replay")
    shiny::updateSelectInput(session, "baseline", selected = reference())
    shiny::updateRadioButtons(session, "estimator", selected = "bayes")
    shiny::updateSliderInput(session, "step", value = step())
    shiny::updateSliderInput(session, "prior_scale", value = 1)
    shiny::updateNumericInput(session, "min_votes", value = 1000)
    shiny::updateSelectizeInput(session, "exclude", selected = character())
    shiny::updateTabsetPanel(session, "page", selected = "lab")
  })
}
