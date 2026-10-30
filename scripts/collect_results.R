# Run from the project root. This script starts no scheduler or background agent.
source("R/model.R")
source("R/feeds.R")
source("R/collector.R")
source("scripts/collector_functions.R")

collector_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste("Usage: Rscript scripts/collect_results.R [--once | --watch] [--publish]",
    "       [--interval=300] [--ky-file=path/to/ky.csv | --ky-dir=data/live/ky-downloads]", sep = "\n")
  if ("--help" %in% args) {cat(usage, "\n"); return(invisible(TRUE))}
  unknown <- args[!grepl("^(--once|--watch|--publish|--interval=[0-9]+|--ky-file=.+|--ky-dir=.+)$", args)]
  if (length(unknown) || all(c("--once", "--watch") %in% args)) stop(usage)
  interval_arg <- args[startsWith(args, "--interval=")]
  ky_arg <- args[startsWith(args, "--ky-file=")]
  ky_dir_arg <- args[startsWith(args, "--ky-dir=")]
  if (length(interval_arg) > 1L || length(ky_arg) > 1L || length(ky_dir_arg) > 1L ||
      (length(ky_arg) && length(ky_dir_arg))) stop(usage)
  interval <- if (length(interval_arg)) as.numeric(sub("--interval=", "", interval_arg)) else 300
  if (!is.finite(interval) || interval < 300) stop("Poll no more often than every 300 seconds.")
  ky_file <- if (length(ky_arg)) sub("--ky-file=", "", ky_arg) else NULL
  ky_dir <- if (length(ky_dir_arg)) sub("--ky-dir=", "", ky_dir_arg) else NULL
  publish <- "--publish" %in% args
  watch <- "--watch" %in% args
  folder <- "data/live/collector"
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  lock <- file.path(folder, "lock")
  if (!dir.create(lock, showWarnings = FALSE)) stop("Collector lock exists. Stop the other collector first. If none is running, remove data/live/collector/lock and try again.")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  writeLines(as.character(Sys.getpid()), file.path(lock, "pid"))
  local_file <- file.path(folder, "latest.json")
  previous <- if (file.exists(local_file)) read_collector_snapshot(local_file) else NULL
  # A restarted collector can retain previously published totals on a first-fetch failure.
  if (is.null(previous)) previous <- tryCatch(suppressWarnings(fetch_collector_snapshot()), error = function(e) NULL)
  cat(if (watch) "Collector running; Ctrl+C stops it.\n" else "Collecting one snapshot.\n")
  repeat {
    snapshot <- collect_results(previous, ky_file, interval, ky_dir = ky_dir)
    write_collector_snapshot(snapshot, local_file)
    archive <- file.path(folder, "archive", paste0(gsub("[-:]", "", snapshot$generated_at), ".json"))
    write_collector_snapshot(snapshot, archive)
    previous <- snapshot
    cat(collector_status_text(snapshot), "\n")
    published <- TRUE
    if (publish) published <- tryCatch({
      sha <- publish_collector_snapshot(snapshot)
      cat("Published ", substr(sha, 1, 7), " to ", collector_config$url, "\n", sep = "")
      TRUE
    }, error = function(e) {message(conditionMessage(e)); message("Snapshot remains saved locally; next poll will retry publication."); FALSE})
    if (!watch) {
      if (!published) stop("Collection saved, but publication failed.")
      return(invisible(snapshot))
    }
    cat("Next collection in", interval, "seconds.\n")
    Sys.sleep(interval)
  }
}
collector_main()
