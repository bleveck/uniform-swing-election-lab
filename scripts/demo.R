# A minimal version for teaching directly in R. No Shiny or network required.
source("R/model.R")
baseline <- read.csv("data/president_2024_current_map.csv")
snapshots <- read.csv("data/replay_president.csv")
snapshot <- snapshots[snapshots$step == 12, ]
estimate <- estimate_swing(baseline, snapshot, min_votes = 1000)
cat(sprintf("Average House minus presidential Democratic two-party share: %+.2f pp\n", estimate$swing_pp))
projection <- project_house(baseline, estimate$swing_pp)
print(seat_counts(projection))
print(estimate$used[, c("district_id", "d_share_2024", "current_d_share", "swing_pp")], row.names = FALSE)
