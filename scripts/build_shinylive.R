# Export the same teaching app with only browser-compatible data access.
# Run from the repository root; outputs/ is intentionally ignored by Git.
stage_shinylive <- function(path) {
  source("scripts/deployment_files.R", local = TRUE)
  files <- setdiff(deployment_files(), "R/feeds.R")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (length(list.files(path, all.files = TRUE, no.. = TRUE))) stop("Staging directory must be empty.")
  for (file in files) {
    target <- file.path(path, file)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(file, target)) stop("Could not stage ", file)
  }
  app <- readLines(file.path(path, "app.R"), warn = FALSE)
  feed_source <- which(app == 'source("R/feeds.R")')
  if (length(feed_source) != 1L) stop("App entry point changed; review the browser export.")
  app[feed_source] <- 'source("R/results.R")'
  writeLines(c('options(election_lab.browser = TRUE)', app), file.path(path, "app.R"))
  invisible(files)
}

build_shinylive <- function(dest = "outputs/shinylive-site") {
  if (!requireNamespace("shinylive", quietly = TRUE) ||
      utils::packageVersion("shinylive") != "0.5.0") stop("Install shinylive 0.5.0 to build this site.")
  stage <- tempfile("election-lab-browser-")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  stage_shinylive(stage)
  shinylive::export(stage, dest, wasm_packages = TRUE, assets_version = "0.10.12",
    max_filesize = 100 * 1024^2, quiet = FALSE,
    template_params = list(title = "Election-night lab · Shinylive"))
  invisible(dest)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  build_shinylive(if (length(args)) args[1] else "outputs/shinylive-site")
}
