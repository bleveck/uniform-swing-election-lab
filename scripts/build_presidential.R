# The Downballot provides exact votes on both sets of boundaries.
source("R/model.R")
read_totals <- function(path, skip, d_col, r_col) {
  x <- read.csv(path, skip = skip, header = FALSE, stringsAsFactors = FALSE)
  x <- x[grepl("^[A-Z]{2}-(AL|[0-9]{2})$", x[[1]]), ]
  num <- function(v) as.numeric(gsub(",", "", v, fixed = TRUE))
  data.frame(district_id = sub("-AL$", "-01", x[[1]]), d_votes = num(x[[d_col]]), r_votes = num(x[[r_col]]))
}
old <- read_totals("data/raw/president_2024_on_2024_lines.csv", 3, 4, 5)
new <- read_totals("data/raw/president_2024_on_2026_lines.csv", 4, 5, 6)
house <- read.csv("data/house_2024.csv")
stopifnot(nrow(old) == 435, nrow(new) == 435, !anyDuplicated(new$district_id),
          setequal(house$district_id, new$district_id))
# Missouri's proposed map was reversed in September. Explicitly restore old-map
# totals even if a downloaded spreadsheet still contains the proposed map.
new[new$district_id %in% old$district_id[grepl("^MO-", old$district_id)], ] <- old[grepl("^MO-", old$district_id), ]
new$state <- substr(new$district_id, 1, 2)
new$d_share_2024 <- new$d_votes / (new$d_votes + new$r_votes)
new$winner_2024 <- ifelse(new$d_share_2024 > .5, "D", "R")
new$contested <- TRUE
# A baseline already aggregated to current boundaries needs no exclusion.
new$boundary_changed <- FALSE
stopifnot(all(is.finite(new$d_share_2024)), all(new$d_share_2024 > 0 & new$d_share_2024 < 1))
write.csv(new, "data/president_2024_current_map.csv", row.names = FALSE)
comparison <- merge(old, new[, c("district_id", "d_votes", "r_votes")], by = "district_id", suffixes = c("_old", "_new"))
comparison$old_d_share <- with(comparison, d_votes_old / (d_votes_old + r_votes_old))
comparison$new_d_share <- with(comparison, d_votes_new / (d_votes_new + r_votes_new))
comparison$share_change_pp <- 100 * (comparison$new_d_share - comparison$old_d_share)
comparison$margin_change_pp <- 2 * comparison$share_change_pp
write.csv(comparison, "data/redistricting_comparison.csv", row.names = FALSE)
print(comparison[comparison$district_id %in% watch_districts, c(1, 6:9)], row.names = FALSE)
