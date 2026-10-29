library(shiny)
library(ggplot2)
source("R/model.R")
source("R/bayes.R")
source("R/feeds.R")
source("R/collector.R")
source("R/plots.R")
source("R/historical_returns.R", local = TRUE)
source("R/introduction.R", local = TRUE)

house_baseline <- read.csv("data/house_2024.csv")
pres_baseline <- read.csv("data/president_2024_current_map.csv")
replay <- read.csv("data/replay.csv", stringsAsFactors = FALSE)
pres_replay <- read.csv("data/replay_president.csv", stringsAsFactors = FALSE)
redistricting <- read.csv("data/redistricting_comparison.csv")
history <- read.csv("data/historical_midterms.csv", stringsAsFactors = FALSE)
historical_prior <- fit_midterm_prior(history, president_party = "R")
historical_districts <- intro_districts(read.csv("data/historical_pair_audit.csv", stringsAsFactors = FALSE))
replay_path <- intro_replay_path(house_baseline, replay, historical_prior)
pres_history <- read.csv("data/historical_president_midterms.csv", stringsAsFactors = FALSE)
pres_prior <- fit_midterm_prior(pres_history, president_party = "R")
pres_bundle <- list(history = pres_history, prior = pres_prior,
  districts = intro_districts(read.csv("data/historical_president_pair_audit.csv", stringsAsFactors = FALSE)),
  path = intro_replay_path(pres_baseline, pres_replay, pres_prior))
ca13_returns <- prepare_ca13_returns(read.csv("data/ca13_2024_returns.csv", stringsAsFactors = FALSE), house_baseline)
fmt_pp <- function(x) if (is.finite(x)) sprintf("%+.1f pp", x) else "Awaiting data"
pct <- function(x) ifelse(is.finite(x), sprintf("%.1f%%", 100 * x), "—")
panel <- function(title, subtitle = NULL, ...) tags$section(class = "panel-card", tags$h3(title),
  if (!is.null(subtitle)) tags$p(class = "panel-subtitle", subtitle), ...)

ui <- fluidPage(
  title = "Election-night lab",
  theme = bslib::bs_theme(version = 5, bg = "#f3f5f7", fg = "#172f46", primary = "#2165ad",
    base_font = "system-ui", heading_font = "system-ui"),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$script(HTML("$(function() { $(document).on('shown.bs.tab', '#page a[data-value]', function() { window.scrollTo(0, 0); }); });"))),
  tags$header(class = "masthead",
    tags$div(class = "eyebrow", "ELECTION NIGHT LAB / CLASSROOM EDITION"),
    tags$h1("Suppose you slept through the election cycle."),
    tags$p("You wake up on election night. What can history and a handful of early results tell you about the House?"),
    tags$span(class = "header-pill", "An illustration of uniform swing · No race calls or win probabilities")),
  tabsetPanel(id = "page", type = "pills", selected = "intro",
    tabPanel("Start here", value = "intro", introduction_ui(ca13_returns)),
    tabPanel("Election-night lab", value = "lab", tags$div(class = "app-grid",
    tags$aside(class = "controls panel-card",
      tags$h2("Run the experiment"),
      radioButtons("mode", "Results source", c("Synthetic replay" = "replay", "Shared laptop snapshots" = "collector", "Official live feeds" = "live", "Upload a CSV" = "csv")),
      conditionalPanel("input.mode == 'replay'",
        tags$p(class = "small-note", "Invented 2026 totals generated on the selected reference map. The early batches are deliberately uneven."),
        sliderInput("step", "Replay snapshot", min = 0, max = 12, value = 6, step = 1,
          animate = animationOptions(interval = 1600, loop = FALSE)),
        tags$p(class = "small-note", "Press ▶ to reveal more cumulative returns. No network connection needed.")),
      selectInput("baseline", "Comparison baseline", c("2024 president · 2026 map" = "president", "2024 House · original map" = "house"), selected = "president"),
      uiOutput("baseline_note"),
      radioButtons("estimator", "Estimate used for seats", c("Raw district average" = "raw", "Bayesian: history + results" = "bayes")),
      conditionalPanel("input.estimator == 'bayes'",
        tags$p(class = "small-note baseline-note", "Each reference has its own fitted prior: House-minus-president performance or House-to-House swing."),
        sliderInput("prior_scale", "Prior SD multiplier", min = .5, max = 3, value = 1, step = .25),
        tags$p(class = "small-note", "District swings are assumed independent conditional on the common swing. Explore the Bayesian update tab.")),
      conditionalPanel("input.mode == 'live'",
        actionButton("refresh", "Fetch official snapshots", class = "btn-primary"),
        checkboxInput("auto", "Refresh every 5 minutes", FALSE),
        tags$p(class = "small-note", "VA JSON · NC ZIP · OH XML. Before Nov 3 at 6 p.m. ET, feed totals are excluded as preparation data. KY uses the CSV fallback."),
        fileInput("manual_live", "Optional KY-06 snapshot (CSV)", accept = ".csv")),
      conditionalPanel("input.mode == 'collector'",
        actionButton("refresh_collector", "Load latest shared snapshot", class = "btn-primary"),
        checkboxInput("auto_collector", "Check for updates every minute", TRUE),
        tags$p(class = "small-note", "One instructor laptop collects VA, NC, and OH every five minutes. Everyone reads the same shared file. KY-06 appears when the instructor supplies a manual entry."),
        tags$p(class = "small-note", "The laptop must keep running. Fetch failures retain previous totals; data older than 15 minutes are labeled STALE. Preparation/test data remain excluded.")),
      conditionalPanel("input.mode == 'csv'", fileInput("upload", "Cumulative district totals (.csv)", accept = ".csv"),
        downloadButton("template", "Download CSV template")),
      tags$hr(),
      numericInput("min_votes", "Minimum D + R votes per district", value = 1000, min = 1, step = 1000),
      selectizeInput("exclude", "Exclude districts", choices = watch_districts, multiple = TRUE,
        options = list(placeholder = "Choose any district…")),
      tags$p(class = "small-note", "Every included district gets one equal vote in the average. The vote threshold is a filter, not a correction for reporting bias."),
      tags$hr(),
      downloadButton("download", "Download district calculation"),
      tags$p(class = "small-note", "Teaching idea: exclude the biggest outlier. How much does the implied House change?")),
    tags$main(
      uiOutput("mode_banner"), uiOutput("problem"),
      tags$div(class = "metric-grid", uiOutput("swing_card"), uiOutput("bayes_card"), uiOutput("house_card"), uiOutput("district_card")),
      tabsetPanel(id = "view", type = "pills",
        tabPanel("The experiment",
          tags$div(class = "chart-grid",
            panel("Where the estimate comes from", "Dots compare House returns with the selected reference. Dashed: raw mean. Purple: Bayesian mean. Gray dots are excluded.", plotOutput("district_plot", height = "350px")),
            panel("From vote share to seats", "Compare raw and Bayesian shifts on the same seat curve. The selected method drives the seat graphic below.", plotOutput("seat_plot", height = "350px"))),
          panel("435 seats, one common shift", uiOutput("map_caption"), plotOutput("waffle", height = "275px")),
          panel("Show the arithmetic", "Votes are cumulative. A newer snapshot replaces the previous one; it is never added to it.", uiOutput("calculation"),
            tags$div(class = "table-scroll", tableOutput("district_table")))),
        tabPanel("Bayesian update",
          panel("What history adds", uiOutput("bayes_description"),
            plotOutput("bayes_density", height = "320px"),
            uiOutput("bayes_arithmetic")),
          panel("The prior comes from past midterms", "Each point is one election’s mean swing against the president’s party, not a seat loss or a vote-weighted national total.",
            plotOutput("history_plot", height = "290px"),
            uiOutput("history_note"),
            tags$p("Republican presidents’ midterm D-share gains and Democratic presidents’ midterm D-share losses are both positive on this history axis. Gains for the president’s party remain in the sample with a negative sign. For 2026, positive swing against the Republican president means positive Democratic swing."),
            tags$div(class = "table-scroll", tableOutput("history_table")),
            downloadButton("history_download", "Download historical prior sample"))),
        tabPanel("Redistricting",
          panel("Compare the same election on two maps", "2024 Harris two-party share, before and after redistricting. A share change is half the change in the D–R margin.",
            tags$p("The presidential option uses a consistent 2026 map nationwide. Its estimate is a cross-office difference: 2026 House vote share minus 2024 presidential vote share. It is not a House-to-House swing."),
            tags$p("Adding the presidential geography change to a 2024 House result is another possible proxy, but moving incumbents, split districts, and uncontested races make that adjustment less straightforward. This first demo keeps the two baselines explicit."),
            tableOutput("redistrict_table"),
            tags$p(class = "small-note", "Source: The Downballot. Missouri uses its 2024 boundaries after the proposed map was reversed. States with new maps are conservatively excluded from the live House-baseline estimate, even if an individual district was unchanged."))),
        tabPanel("Method & sources",
          panel("A deliberately small model",
            tags$p("For each included district: D share = D votes / (D votes + R votes). Change = current D share − baseline D share. Take the simple average, then add it to every district’s baseline share, clipping at 0% and 100%. Above 50% implies a Democratic seat; below 50% implies a Republican seat. Exact ties remain unresolved."),
            tags$p("In House mode, the 38 contests without both major parties in 2024 are held at their 2024 winner. Fusion ballot lines are combined with their candidate. Maine uses the final ranked-choice tally printed by the Clerk; Alaska uses the printed first-choice totals. These are simplifications, not imputed competitive vote shares."),
            tags$p("Only the ten House races listed in the post are used. Senate and governor races have different offices and baselines, so they are not pooled into this average."),
            tags$p("Early votes and reporting districts are not a random sample. Ballot method, geography, candidate effects, turnout, and the selected watchlist can bias the estimate. Bayesian intervals are conditional on the displayed Normal model and its noise assumptions; they are not calibrated forecast intervals. No vote-level binomial precision or majority probabilities are supplied."),
            tags$p("The selected reference determines the historical prior. The presidential model fits midterm House share minus the preceding presidential share; the House model fits change since the preceding House election. Each is oriented against the president’s party and fitted separately. Its SD is the historical between-election SD, not the standard error of the historical mean. District deviations are assumed independent conditional on the common shift, giving likelihood variance σ²/n. Cumulative snapshots replace earlier ones."),
            tags$p("Live errors preserve the last successful snapshot for that provider and flag it as stale. Check the provider status and timestamps before interpreting a change. Test feeds are excluded.")),
          panel("Data you can inspect",
            tags$ul(
              tags$li(tags$a(href = "https://clerk.house.gov/member_info/electionInfo/2024/statistics2024.pdf", target = "_blank", "U.S. House Clerk: official 2024 results")),
              tags$li(tags$a(href = "https://www.the-downballot.com/p/the-downballots-calculations-of-presidential", target = "_blank", "The Downballot: presidential results on both maps")),
              tags$li(tags$a(href = "https://www.census.gov/programs-surveys/decennial-census/about/rdo/congressional-districts.html", target = "_blank", "Census: boundaries for the 2026 election")),
              tags$li(tags$a(href = "https://doi.org/10.17605/OSF.IO/MJVKB", target = "_blank", "Wolf / King / CLEA: historical district returns")),
              tags$li(tags$a(href = "https://doi.org/10.7910/DVN/29559", target = "_blank", "Gary Jacobson: House and presidential district shares through 2014")),
              tags$li(tags$a(href = "https://www.shirokuriwaki.com/ccesMRPprep/reference/cd_info.html", target = "_blank", "ccesMRPprep / The Downballot: presidential shares on named district maps")),
              tags$li(tags$a(href = "https://github.com/MEDSL/constituency-returns", target = "_blank", "MIT Election Lab: 2016 and 2018 returns")),
              tags$li(tags$a(href = "https://github.com/JeffreyBLewis/congressional-district-boundaries", target = "_blank", "Lewis et al.: historical boundary vintages")),
              tags$li(tags$a(href = "https://www.elections.virginia.gov/results/", target = "_blank", "Virginia ELECT results and media export")),
              tags$li(tags$a(href = "https://er.ncsbe.gov/downloads.html?election_dt=11/03/2026", target = "_blank", "North Carolina election downloads")),
              tags$li(tags$a(href = "https://liveresults.ohiosos.gov/", target = "_blank", "Ohio SOS election reporting")),
              tags$li(tags$a(href = "https://vrsws.sos.ky.gov/liveresults/", target = "_blank", "Kentucky election reporting (CSV fallback)"))),
            tags$p("Presidential-reference research checked October 29, 2026; House-prior research October 28; live-feed research October 27. Feed schemas may change before election night. Public feeds are unofficial until certification."))))))))
)

server <- function(input, output, session) {
  live_data <- reactiveVal(empty_results())
  statuses <- reactiveVal("No official snapshots fetched yet.")
  upload_error <- reactiveVal(NULL)
  uploaded <- reactiveVal(empty_results())
  manual <- reactiveVal(empty_results())
  manual_error <- reactiveVal(NULL)
  shared_snapshot <- reactiveVal(NULL)
  shared_error <- reactiveVal(NULL)
  shared_now <- reactive({invalidateLater(60000, session); Sys.time()})
  introduction_server(input, output, session, historical_districts, history, historical_prior, replay_path, ca13_returns, pres_bundle)
  observeEvent(input$upload, {
    uploaded(empty_results()); upload_error(NULL)
    if (is.null(input$upload)) return()
    tryCatch(uploaded(validate_results(read.csv(input$upload$datapath, stringsAsFactors = FALSE))),
      error = function(e) upload_error(conditionMessage(e)))
  }, ignoreNULL = FALSE)
  observeEvent(input$manual_live, {
    manual(empty_results()); manual_error(NULL)
    if (is.null(input$manual_live)) return()
    tryCatch({
      x <- validate_results(read.csv(input$manual_live$datapath, stringsAsFactors = FALSE))
      if (any(x$district_id != "KY-06")) stop("This live supplement accepts KY-06 only. Use CSV mode for other districts.")
      manual(x)
    }, error = function(e) manual_error(conditionMessage(e)))
  }, ignoreNULL = FALSE)

  refresh_live <- function() {
    messages <- character()
    current <- live_data()
    withProgress(message = "Fetching official cumulative snapshots", value = 0, {
      for (state in names(feed_config)) {
        incProgress(1 / 3, detail = state)
        tryCatch({
          x <- fetch_feed(state)
          current <- rbind(current[substr(current$district_id, 1, 2) != state, ], x)
          updated <- unique(x$source_updated_at[!is.na(x$source_updated_at)])
          messages <- c(messages, paste0(state, ": fetched ", utc_now(), if (any(x$is_test)) " · test/pre-election data excluded" else " · OK",
            if (length(updated)) paste0(" · provider timestamp: ", updated[1]) else " · provider timestamp unavailable"))
        }, error = function(e) {
          messages <<- c(messages, paste0(state, ": STALE / unavailable — ", conditionMessage(e), ". Last successful snapshot retained, if any."))
        })
      }
    })
    live_data(current); statuses(paste(messages, collapse = "\n"))
  }
  observeEvent(input$refresh, refresh_live())
  refresh_shared <- function() {
    tryCatch({
      snapshot <- fetch_collector_snapshot()
      shared_snapshot(snapshot)
      shared_error(NULL)
    }, error = function(e) {
      shared_error("Could not load the published snapshot; retry or check that the laptop is publishing.")
    })
  }
  observeEvent(input$refresh_collector, refresh_shared())
  observe({
    if (identical(input$mode, "collector")) {
      if (isTRUE(input$auto_collector)) invalidateLater(60000, session)
      isolate(refresh_shared())
    }
  })
  observe({
    if (isTRUE(input$auto) && identical(input$mode, "live")) {
      invalidateLater(300000, session)
      isolate(refresh_live())
    }
  })

  baseline <- reactive(if ((input$baseline %||% "president") == "president") pres_baseline else house_baseline)
  active_history <- reactive(if ((input$baseline %||% "president") == "president") pres_history else history)
  active_prior <- reactive(if ((input$baseline %||% "president") == "president") pres_prior else historical_prior)
  results <- reactive(switch(input$mode,
    replay = { r <- if ((input$baseline %||% "president") == "president") pres_replay else replay; r[r$step == input$step, names(empty_results())] },
    live = rbind(live_data(), manual()),
    collector = {x <- shared_snapshot(); if (is.null(x)) empty_results() else x$results}, csv = uploaded()))
  estimate <- reactive({
    threshold <- input$min_votes
    if (is.null(threshold) || !is.finite(threshold) || threshold < 1) threshold <- 1000
    estimate_swing(baseline()[baseline()$district_id %in% watch_districts, ], results(),
      threshold, live = input$mode != "replay", exclude = input$exclude)
  })
  bayesian <- reactive({
    normal_swing_update(estimate()$swing_pp, estimate()$n, active_prior(),
      prior_sd_multiplier = input$prior_scale %||% 1)
  })
  selected_swing <- reactive({
    if (identical(input$estimator, "bayes") && !is.null(bayesian())) bayesian()$mean_pp else estimate()$swing_pp
  })
  selected_label <- reactive(if (identical(input$estimator, "bayes") && !is.null(bayesian())) "Bayesian" else "Raw")
  projection <- reactive({
    req(is.finite(selected_swing()))
    project_house(baseline(), selected_swing())
  })

  output$baseline_note <- renderUI(tags$p(class = "small-note baseline-note", if (input$baseline == "house")
    "House-to-House comparison. National seats use the 2024 map; changed-map states are excluded from live estimation." else
    "Current 2026 boundaries. Compares House returns with Harris’s 2024 share; this is a cross-office proxy."))
  output$mode_banner <- renderUI(tags$div(class = paste("mode-banner", input$mode),
    tags$strong(switch(input$mode, replay = paste("SYNTHETIC REPLAY · SNAPSHOT", input$step, "OF 12"),
      live = "OFFICIAL FEEDS · UNOFFICIAL RETURNS", collector = "SHARED LAPTOP SNAPSHOT · UNOFFICIAL RETURNS", csv = "USER-SUPPLIED CSV · CUMULATIVE TOTALS")),
    tags$span(if (input$baseline == "house") "2024-map thought experiment" else "2026-map presidential proxy"),
    if (input$mode == "live") tags$pre(statuses()),
    if (input$mode == "collector") tags$pre(collector_status_text(shared_snapshot(), shared_now(), shared_error()))))
  output$problem <- renderUI({
    error <- if (input$mode == "csv") upload_error() else if (input$mode == "live") manual_error() else NULL
    if (!is.null(error)) tags$div(class = "error-banner", paste("CSV not loaded:", error))
  })
  metric <- function(label, value, detail) tags$div(class = "metric", tags$div(class = "metric-label", label),
    tags$div(class = "metric-value", value), tags$div(class = "metric-detail", detail))
  output$swing_card <- renderUI(metric(if (input$baseline == "president") "RAW HOUSE − PRESIDENT" else "RAW HOUSE SWING", fmt_pp(estimate()$swing_pp), "Percentage points · equal district weights"))
  output$bayes_card <- renderUI({
    post <- bayesian()
    metric("BAYESIAN CHANGE IN D SHARE", if (is.null(post)) "—" else fmt_pp(post$mean_pp),
      if (post$prior_only) "Prior only · no eligible returns" else sprintf("%.0f%% history + %.0f%% current data", 100 * post$prior_weight, 100 * post$data_weight))
  })
  output$house_card <- renderUI({
    s <- selected_swing()
    value <- if (is.finite(s)) { n <- seat_counts(project_house(baseline(), s)); paste("D", n[["D"]], " / R", n[["R"]], if (n[["Tie"]]) paste(" / tied", n[["Tie"]]) else "") } else "—"
    metric(paste(toupper(selected_label()), "IMPLIED HOUSE"), value,
      if (identical(selected_label(), "Bayesian") && bayesian()$prior_only) "Prior-only illustration · no eligible returns" else "435 seats · 218 needed for a majority")
  })
  output$district_card <- renderUI(metric("DISTRICTS IN THE AVERAGE", paste0(estimate()$n, " / 10"), "See the table for every inclusion decision"))
  output$district_plot <- renderPlot(swing_plot(estimate(), bayesian()), res = 110)
  output$seat_plot <- renderPlot(seats_plot(baseline(), estimate()$swing_pp, bayesian(), selected_label()), res = 110)
  output$waffle <- renderPlot({ validate(need(is.finite(selected_swing()), "No eligible results yet. Advance the replay or load a valid snapshot.")); waffle_plot(projection()) }, res = 110)
  output$map_caption <- renderUI(tags$p(class = "panel-subtitle", if (input$baseline == "house")
    "One square per district, ordered from most to least Democratic. Uses 2024 boundaries; one-party contests are held fixed." else
    "One square per current district, ordered from most to least Democratic. Baseline is 2024 presidential share on 2026 boundaries."))
  output$calculation <- renderUI({
    x <- estimate()$used
    if (!nrow(x)) return(tags$p("No districts meet the inclusion rules yet."))
    x <- x[order(x$district_id), ][1, ]
    tags$p(class = "formula", sprintf("%s: %s ÷ (%s + %s) = %s. Compared with %s in 2024, that is %s.",
      x$district_id, format(x$d_votes_current, big.mark = ","), format(x$d_votes_current, big.mark = ","),
      format(x$r_votes_current, big.mark = ","), pct(x$current_d_share), pct(x$d_share_2024), fmt_pp(x$swing_pp)))
  })
  output$bayes_description <- renderUI({
    post <- bayesian()
    target <- if (input$baseline == "president") "House-minus-president performance" else "House-to-House swing"
    tags$p(sprintf("For %s, the 2026 prior is Normal(%+.2f, %.2f²) pp of Democratic two-party share. With %d included district%s, the posterior is Normal(%+.2f, %.2f²). Its model-conditional 95%% interval is [%+.2f, %+.2f] pp.%s", target, post$prior_mean_pp, post$prior_sd_pp, post$n, if (post$n == 1) "" else "s", post$mean_pp, post$sd_pp, post$lower_pp, post$upper_pp, if (post$prior_only) " With no returns, the posterior equals the prior." else ""))
  })
  output$bayes_density <- renderPlot({
    bayes_density_plot(bayesian(), estimate()$swing_pp, if (input$baseline == "president")
      "House − presidential Democratic share (percentage points)" else "House-to-House Democratic share swing (percentage points)")
  }, res = 110)
  output$bayes_arithmetic <- renderUI({
    post <- bayesian()
    if (is.null(post)) return(NULL)
    tags$div(class = "formula",
      tags$p("θ ~ Normal(μ₀, τ²); current raw average ȳ | θ ~ Normal(θ, s²)."),
      tags$p(sprintf("s² = σ² / n, where the pooled historical cross-district residual SD for this reference σ = %.2f pp. District deviations are assumed independent conditional on θ. More ballots in the same district are not new independent observations.", active_prior()$district_sd_pp)),
      if (post$prior_only) tags$p("n = 0: posterior = prior; current-data weight = 0%.") else tagList(
        tags$p(sprintf("Data SE s = %.2f pp. Data weight w = τ² / (τ² + s²) = %.3f.", post$data_se_pp, post$data_weight)),
        tags$p(sprintf("Posterior mean = (1 − w)μ₀ + wȳ = %.3f × (%+.2f) + %.3f × (%+.2f) = %+.2f pp.", post$prior_weight, post$prior_mean_pp, post$data_weight, estimate()$swing_pp, post$mean_pp)),
        tags$p("Posterior variance = 1 / (1/τ² + 1/s²).")),
      tags$p("This is an empirical, plug-in Normal prior: uncertainty about its fitted mean and SD is not integrated out. Conditional independence and the Normal likelihood are teaching assumptions; the interval is conditional on this model."))
  })
  output$history_note <- renderUI({
    p <- active_prior()
    tags$p(sprintf("This reference uses %d midterms from %d through %d, giving each election one equal weight. Post-census midterms 1962, 1982, 2002, and 2022 are excluded. %s", p$n_elections, p$first_year, p$last_year,
      if (input$baseline == "president") "Jacobson supplies two-party presidential and House shares through 2014, with his redrawn-district flag respected. The Downballot / ccesMRPprep supplies 2016 presidential shares on 2018 lines for the extension. Presidential district shares are unavailable for 1946 and 1950." else "This House-to-House sample excludes changed-map states and requires major-party competition in both elections."))
  })
  output$history_plot <- renderPlot(history_prior_plot(active_history(), active_prior()), res = 110)
  output$history_table <- renderTable({ h <- active_history(); data.frame(Year = h$year, President = h$president,
    Party = h$president_party, Districts = h$n_districts,
    `Performance toward out-party (pp)` = ifelse(h$included, sprintf("%+.2f", h$against_president_pp), "—"),
    Sample = ifelse(h$included, "Included", h$exclusion), check.names = FALSE) }, striped = TRUE, na = "—")
  output$district_table <- renderTable({
    x <- estimate()$districts; x <- x[match(watch_districts, x$district_id), ]
    data.frame(District = x$district_id, `2024 D share` = pct(x$d_share_2024),
      `D votes` = ifelse(is.na(x$d_votes_current), "—", format(x$d_votes_current, big.mark = ",", trim = TRUE)),
      `R votes` = ifelse(is.na(x$r_votes_current), "—", format(x$r_votes_current, big.mark = ",", trim = TRUE)),
      `Current D share` = pct(x$current_d_share), `Change (pp)` = ifelse(is.finite(x$swing_pp), sprintf("%+.2f", x$swing_pp), "—"),
      Status = x$reason, check.names = FALSE)
  }, striped = TRUE, bordered = FALSE, spacing = "s", na = "—")
  output$redistrict_table <- renderTable({
    x <- redistricting[match(watch_districts, redistricting$district_id), ]
    data.frame(District = x$district_id, `Old-map Harris share` = pct(x$old_d_share),
      `New-map Harris share` = pct(x$new_d_share), `Share change (pp)` = sprintf("%+.2f", x$share_change_pp),
      `D–R margin change (pp)` = sprintf("%+.2f", x$margin_change_pp), check.names = FALSE)
  }, striped = TRUE)
  output$download <- downloadHandler(filename = function() paste0("swing-calculation-", input$mode, ".csv"),
    content = function(file) {
      x <- estimate()$districts
      x$raw_mean_pp <- estimate()$swing_pp
      x$bayes_mean_pp <- if (is.null(bayesian())) NA_real_ else bayesian()$mean_pp
      x$selected_method <- selected_label()
      x$reference <- input$baseline
      x$selected_swing_pp <- selected_swing()
      write.csv(x, file, row.names = FALSE, na = "")
    })
  output$history_download <- downloadHandler(filename = "historical-midterm-prior.csv",
    content = function(file) write.csv(active_history(), file, row.names = FALSE, na = ""))
  output$template <- downloadHandler(filename = "results-template.csv", content = function(file) file.copy("data/results_template.csv", file))
}

shinyApp(ui, server)
