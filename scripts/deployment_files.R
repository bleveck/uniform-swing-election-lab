# Runtime files only: source archives and data-rebuild tools stay in GitHub,
# but are not needed in the hosted app bundle.
deployment_files <- function() {
  files <- c("app.R", list.files("R", recursive = TRUE, full.names = TRUE),
    list.files("www", recursive = TRUE, full.names = TRUE),
    file.path("data", c("house_2024.csv", "president_2024_current_map.csv",
      "replay.csv", "replay_president.csv", "redistricting_comparison.csv",
      "historical_midterms.csv", "historical_pair_audit.csv",
      "historical_president_midterms.csv", "historical_president_pair_audit.csv",
      "ca13_2024_returns.csv", "results_template.csv")))
  missing <- files[!file.exists(files)]
  if (length(missing)) stop("Missing deployment files: ", paste(missing, collapse = ", "))
  sort(unique(files))
}
