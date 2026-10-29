# Invented cumulative totals on each reference map. No real 2026 returns here.
source("R/model.R")
for (reference in c("house", "president")) {
b <- read.csv(if (reference == "house") "data/house_2024.csv" else "data/president_2024_current_map.csv")
b <- b[match(watch_districts, b$district_id), ]
start <- c(1, 2, 2, 3, 4, 4, 5, 5, 6, 6)
local <- c(1.0, -.6, .8, -1.1, .5, -.8, -1.2, 1.1, .4, -.1)
bias <- c(4, -3, 2, -2, 3, -2, 2, -3, 2, -1)
rows <- list()
for (step in 0:12) for (i in seq_len(nrow(b))) {
  progress <- pmin(1, pmax(0, (step - start[i] + 1) / (13 - start[i])))
  n <- round((b$d_votes[i] + b$r_votes[i]) * .82 * progress)
  share <- b$d_share_2024[i] + (3 + local[i] + bias[i] * (1 - progress)) / 100
  d <- round(n * share)
  rows[[length(rows) + 1L]] <- data.frame(step = step, district_id = b$district_id[i],
    d_votes_current = d, r_votes_current = n - d, election_date = "2026-11-03",
    source = if (reference == "house") "SYNTHETIC classroom replay" else "SYNTHETIC classroom replay: presidential reference on 2026 map", fetched_at = NA_character_, source_updated_at = NA_character_, is_test = FALSE)
}
write.csv(do.call(rbind, rows), if (reference == "house") "data/replay.csv" else "data/replay_president.csv", row.names = FALSE, na = "")
}
