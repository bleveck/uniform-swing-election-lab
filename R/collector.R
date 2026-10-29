# Public snapshot format shared by the laptop collector and app readers.
collector_config <- list(repo = "bleveck/uniform-swing-election-lab",
  branch = "codex/snapshots", stale_seconds = 900,
  url = "https://raw.githubusercontent.com/bleveck/uniform-swing-election-lab/codex/snapshots/latest.json")

collector_stamp <- function(time = Sys.time()) format(time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
collector_time <- function(x) {
  x <- as.character(x)
  parsed <- as.POSIXct(strptime(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  bad <- !is.na(x) & (is.na(parsed) | !grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", x) |
    collector_stamp(parsed) != x)
  if (any(bad)) stop("Invalid collector timestamp; expected UTC YYYY-MM-DDTHH:MM:SSZ.")
  parsed
}

validate_collector_snapshot <- function(x, now = Sys.time()) {
  scalar_text <- function(z) is.character(z) && length(z) == 1L && !is.na(z) && nzchar(z)
  if (!is.list(x) || !identical(as.integer(x$schema_version), 1L) ||
      !identical(x$election_date, "2026-11-03") || !scalar_text(x$generated_at)) {
    stop("Wrong collector schema or election date.")
  }
  generated <- collector_time(x$generated_at)
  if (generated > now + 300) stop("Collector snapshot is dated in the future.")
  if (length(x$poll_interval_seconds) != 1L || !is.numeric(x$poll_interval_seconds) ||
      !is.finite(x$poll_interval_seconds) || x$poll_interval_seconds < 300) stop("Invalid collector polling interval.")
  p <- x$providers
  fields <- c("provider", "status", "last_attempt_at", "last_success_at", "error")
  if (!is.data.frame(p) || !all(fields %in% names(p)) || nrow(p) != 4L ||
      anyDuplicated(p$provider) || !setequal(p$provider, c("VA", "NC", "OH", "KY"))) stop("Invalid collector provider table.")
  p <- p[, fields, drop = FALSE]
  p[] <- lapply(p, as.character)
  if (anyNA(p$status) || any(!p$status %in% c("ok", "error", "missing")) || anyNA(p$last_attempt_at)) stop("Invalid collector provider status.")
  attempt <- collector_time(p$last_attempt_at)
  success <- collector_time(p$last_success_at)
  if (any(attempt > generated + 300) || any(success > generated + 300, na.rm = TRUE)) stop("Provider timestamp exceeds collection time.")
  if (any(p$status == "ok" & is.na(success))) stop("Successful provider is missing its timestamp.")
  results <- x$results
  if (is.list(results) && length(results) == 0L) results <- empty_results()
  if (!is.data.frame(results) || !all(names(empty_results()) %in% names(results))) stop("Invalid collector result columns.")
  results <- validate_results(results)
  if (any(!results$district_id %in% watch_districts)) stop("Collector contains districts outside the watchlist.")
  if (nrow(results)) {
    fetched <- collector_time(results$fetched_at)
    if (anyNA(fetched) || any(fetched > generated + 300)) stop("Invalid result retrieval time.")
    for (state in p$provider) {
      rows <- substr(results$district_id, 1, 2) == state
      if (any(rows) && is.na(p$last_success_at[p$provider == state])) stop("Retained results lack a successful fetch time.")
      if (!is.na(p$last_success_at[p$provider == state]) &&
          !setequal(results$district_id[rows], watch_districts[substr(watch_districts, 1, 2) == state])) {
        stop("Collector provider has incomplete watchlist results.")
      }
    }
    # Preparation data must stay excluded even when read after election day.
    opening <- as.POSIXct("2026-11-03 23:00:00", tz = "UTC") # 6 p.m. Eastern on election day
    results$is_test <- results$is_test | fetched < opening | generated < opening | now < opening
  }
  list(schema_version = 1L, election_date = x$election_date, generated_at = x$generated_at,
    poll_interval_seconds = x$poll_interval_seconds, providers = p, results = results)
}

read_collector_snapshot <- function(path, now = Sys.time()) {
  validate_collector_snapshot(jsonlite::fromJSON(path, simplifyVector = TRUE), now)
}

fetch_collector_snapshot <- function(url = collector_config$url, now = Sys.time()) {
  file <- tempfile(fileext = ".json")
  on.exit(unlink(file))
  # A shared minute bucket limits CDN staleness without a unique URL per student.
  url <- paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?", "minute=", floor(as.numeric(now) / 60))
  # webR patches this basic GET for browser use; no curl/socket proxy is needed.
  utils::download.file(url, file, mode = "wb", quiet = TRUE, cacheOK = FALSE)
  read_collector_snapshot(file, now)
}

collector_status_text <- function(snapshot, now = Sys.time(), error = NULL) {
  if (is.null(snapshot)) return(paste("No shared snapshot loaded yet.", error %||% ""))
  age <- function(stamp) floor(max(0, as.numeric(difftime(now, collector_time(stamp), units = "mins"))))
  old <- age(snapshot$generated_at) * 60 >= collector_config$stale_seconds
  lines <- sprintf("%sLaptop last collected: %s · %d min ago", if (old) "STALE · " else "",
    snapshot$generated_at, age(snapshot$generated_at))
  if (!is.null(error)) lines <- c(lines, paste("SHARED FILE UNAVAILABLE:", error, "Last loaded snapshot retained."))
  for (i in seq_len(nrow(snapshot$providers))) {
    p <- snapshot$providers[i, ]
    rows <- snapshot$results[substr(snapshot$results$district_id, 1, 2) == p$provider, ]
    if (is.na(p$last_success_at)) {
      lines <- c(lines, paste0(p$provider, ": ", if (p$status == "missing") "No manual KY-06 totals supplied." else "Unavailable; no successful snapshot yet."))
    } else {
      stale <- p$status != "ok" || age(p$last_success_at) * 60 >= collector_config$stale_seconds
      lines <- c(lines, sprintf("%s: %s%d district%s · last fetched %s · %d min ago%s%s", p$provider,
        if (stale) "STALE · " else "", nrow(rows), if (nrow(rows) == 1) "" else "s", p$last_success_at,
        age(p$last_success_at), if (any(rows$is_test)) " · preparation/test data excluded" else "",
        if (p$status == "error") paste0(" · ", p$error) else ""))
      updated <- unique(as.character(rows$source_updated_at[!is.na(rows$source_updated_at) & nzchar(rows$source_updated_at)]))
      lines <- c(lines, paste0("    Provider timestamp: ", if (length(updated)) paste(updated, collapse = "; ") else "not supplied"))
    }
  }
  paste(lines, collapse = "\n")
}
