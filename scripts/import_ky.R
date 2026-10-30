# Convert manually downloaded Kentucky XML files. No network access/publication.
source("R/results.R")
source("scripts/ky_import_functions.R")

usage <- paste("Usage: Rscript scripts/import_ky.R [--input-dir=data/live/ky-downloads]",
  "       [--output=data/live/ky-import.csv] [--test]", sep = "\n")
args <- commandArgs(trailingOnly = TRUE)
if ("--help" %in% args) {
  cat(usage, "\n")
} else {
  if (any(!grepl("^(--input-dir=.+|--output=.+|--test)$", args))) stop(usage)
  value <- function(prefix, default) {
    matches <- args[startsWith(args, prefix)]
    if (length(matches) > 1L) stop(usage)
    if (length(matches)) substring(matches, nchar(prefix) + 1L) else default
  }
  folder <- value("--input-dir=", "data/live/ky-downloads")
  output <- value("--output=", "data/live/ky-import.csv")
  parsed <- import_ky_downloads(folder, output, force_test = "--test" %in% args)
  cat("Imported ", parsed$contest, "\n", sep = "")
  print(parsed$results, row.names = FALSE)
  cat("Non-overlapping reporting units selected:", nrow(parsed$selected_units), "\n")
  cat("Saved:", output, "\nNothing has been published.\n")
}
