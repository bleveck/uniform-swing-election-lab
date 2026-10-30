# Laptop-only helpers. These files are not part of the hosted runtime bundle.
source("scripts/ky_import_functions.R")

collector_json <- function(snapshot) paste0(jsonlite::toJSON(snapshot, auto_unbox = TRUE,
  dataframe = "rows", na = "null", null = "null", digits = NA, pretty = TRUE), "\n")

write_collector_snapshot <- function(snapshot, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temp <- tempfile("snapshot-", tmpdir = dirname(path))
  on.exit(unlink(temp))
  writeLines(collector_json(snapshot), temp, useBytes = TRUE)
  if (!file.rename(temp, path)) stop("Could not replace local snapshot: ", path)
  invisible(path)
}

collect_results <- function(previous = NULL, ky_file = NULL, interval = 300,
                            fetch = fetch_feed, clock = Sys.time, ky_dir = NULL) {
  if (!is.null(ky_file) && !is.null(ky_dir)) stop("Choose --ky-file or --ky-dir, not both.")
  now <- clock()
  if (!is.null(previous)) previous <- validate_collector_snapshot(previous, now)
  results <- if (is.null(previous)) empty_results() else previous$results
  providers <- if (is.null(previous)) data.frame(provider = c("VA", "NC", "OH", "KY"),
    status = "missing", last_attempt_at = collector_stamp(now), last_success_at = NA_character_,
    error = NA_character_, stringsAsFactors = FALSE) else previous$providers
  for (state in providers$provider) {
    i <- match(state, providers$provider)
    providers$last_attempt_at[i] <- collector_stamp(clock())
    if (state == "KY" && is.null(ky_file) && is.null(ky_dir)) {
      if (any(substr(results$district_id, 1, 2) == "KY")) {
        providers$status[i] <- "error"
        providers$error[i] <- "Manual file not supplied; previous entry retained."
      } else {
        providers$status[i] <- "missing"
        providers$error[i] <- NA_character_
      }
      next
    }
    tryCatch({
      if (state == "KY") {
        if (!is.null(ky_dir)) {
          x <- import_ky_downloads(ky_dir, now = clock())$results
          stamp <- x$fetched_at
        } else {
          x <- validate_results(read.csv(ky_file, stringsAsFactors = FALSE))
          if (nrow(x) != 1L || x$district_id != "KY-06") stop("Manual file must contain exactly KY-06.")
          # Re-reading an unchanged manual file must not make its totals look newer.
          stamp <- collector_stamp(file.info(ky_file)$mtime)
          x$fetched_at <- stamp
          x$source <- "KY SOS manual entry"
        }
        old_ky <- results[results$district_id == "KY-06", , drop = FALSE]
        if (nrow(old_ky) && collector_time(old_ky$fetched_at) > collector_time(stamp)) {
          stop("Kentucky input is older than the retained snapshot.")
        }
      } else {
        x <- validate_results(fetch(state))
        expected <- watch_districts[substr(watch_districts, 1, 2) == state]
        if (!setequal(x$district_id, expected)) stop("Provider omitted an expected watchlist district.")
        stamp <- collector_stamp(clock())
        x$fetched_at <- stamp
      }
      if (collector_time(stamp) < as.POSIXct("2026-11-03 23:00:00", tz = "UTC")) x$is_test <- TRUE
      results <- rbind(results[substr(results$district_id, 1, 2) != state, ], x)
      providers$status[i] <- "ok"
      providers$last_success_at[i] <- stamp
      providers$error[i] <- NA_character_
    }, error = function(e) {
      message(state, ": ", conditionMessage(e))
      providers$status[i] <<- "error"
      # Detailed local errors can contain local file paths; keep them off GitHub.
      providers$error[i] <<- "Fetch or validation failed; previous totals retained if available."
    })
  }
  results <- results[order(results$district_id), , drop = FALSE]
  validate_collector_snapshot(list(schema_version = 1L, election_date = "2026-11-03",
    generated_at = collector_stamp(clock()), poll_interval_seconds = interval,
    providers = providers, results = results), clock())
}

collector_gh_api <- function(endpoint, method = "GET", body = NULL, allow_404 = FALSE) {
  gh <- Sys.which("gh")
  if (!nzchar(gh)) stop("Publishing needs GitHub CLI (gh). Run gh auth login first.")
  input <- tempfile(fileext = ".json"); output <- tempfile(); errors <- tempfile()
  on.exit(unlink(c(input, output, errors)))
  args <- c("api", "--hostname", "github.com", "--method", method, endpoint)
  if (!is.null(body)) {
    jsonlite::write_json(body, input, auto_unbox = TRUE, null = "null", digits = NA)
    args <- c(args, "--input", input)
  }
  status <- suppressWarnings(system2(gh, vapply(args, shQuote, character(1)), stdout = output, stderr = errors))
  text <- paste(readLines(output, warn = FALSE), collapse = "\n")
  error <- paste(readLines(errors, warn = FALSE), collapse = "\n")
  if (status != 0L) {
    if (allow_404 && grepl("HTTP 404", error, fixed = TRUE)) return(NULL)
    stop("GitHub publication failed: ", error)
  }
  jsonlite::fromJSON(text, simplifyVector = FALSE)
}

publish_collector_snapshot <- function(snapshot, api = collector_gh_api) {
  snapshot <- validate_collector_snapshot(snapshot)
  prefix <- paste0("repos/", collector_config$repo)
  branch <- collector_config$branch
  ref <- api(paste0(prefix, "/git/ref/heads/", branch), allow_404 = TRUE)
  content <- collector_json(snapshot)
  message <- paste("Update shared election snapshot", snapshot$generated_at)
  if (is.null(ref)) {
    readme <- paste0("# Shared laptop election snapshots\n\n",
      "Only public watchlist vote totals, source clocks, test flags, and provider status are published here.\n",
      "`latest.json` is replaced cumulatively; failures retain each provider's last successful totals.\n",
      "Preparation/test data are excluded by the app. The snapshot can become stale when the laptop stops.\n",
      "App source and instructions: https://github.com/", collector_config$repo, "\n")
    tree <- api(paste0(prefix, "/git/trees"), "POST", list(tree = list(
      list(path = "latest.json", mode = "100644", type = "blob", content = content),
      list(path = "README.md", mode = "100644", type = "blob", content = readme))))
    commit <- api(paste0(prefix, "/git/commits"), "POST", list(message = message, tree = tree$sha, parents = list()))
    api(paste0(prefix, "/git/refs"), "POST", list(ref = paste0("refs/heads/", branch), sha = commit$sha))
    sha <- commit$sha
  } else {
    endpoint <- paste0(prefix, "/contents/latest.json")
    old <- api(paste0(endpoint, "?ref=", utils::URLencode(branch, reserved = TRUE)))
    remote <- validate_collector_snapshot(jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(old$content))))
    if (collector_time(remote$generated_at) > collector_time(snapshot$generated_at)) stop("A newer snapshot is already published. Check for another collector or a wrong laptop clock.")
    response <- api(endpoint, "PUT", list(message = message, branch = branch, sha = old$sha,
      content = jsonlite::base64_enc(charToRaw(content))))
    sha <- response$commit$sha
  }
  invisible(sha)
}
