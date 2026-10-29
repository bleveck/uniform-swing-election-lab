# Fetch once. Call from a scheduler only if you choose to set one up.
source("R/model.R")
source("R/feeds.R")
snapshots <- lapply(names(feed_config), function(state) tryCatch(fetch_feed(state), error = function(e) {
  message(state, ": ", conditionMessage(e)); empty_results()
}))
results <- do.call(rbind, snapshots)
if (!nrow(results)) stop("No feeds loaded; no output file written.")
dir.create("data/live", showWarnings = FALSE)
file <- file.path("data/live", paste0("snapshot-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), ".csv"))
write.csv(results, file, row.names = FALSE, na = "")
cat("Saved", file, "\n")
print(results)
