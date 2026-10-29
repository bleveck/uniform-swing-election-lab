# Rebuild from the Clerk's official 2024 report, extracted with pdftotext -layout.
# Refresh the source with: Rscript scripts/download_sources.R
source("R/model.R")
lines <- readLines("data/raw/statistics2024.txt", warn = FALSE)
state_names <- toupper(state.name)
state <- NA_character_
district <- 1L
in_house <- FALSE
last_candidate <- NA_integer_
rows <- list()
for (line in lines) {
  text <- trimws(gsub("\f", "", line, fixed = TRUE))
  heading <- sub("—Continued$", "", text)
  if (heading %in% state_names) {
    next_state <- state.abb[match(heading, state_names)]
    if (!identical(state, next_state)) {
      state <- next_state
      in_house <- FALSE
      district <- 1L
    }
  }
  if (grepl("^(AMERICAN SAMOA|DISTRICT OF COLUMBIA|GUAM|PUERTO RICO|VIRGIN ISLANDS)$", heading)) state <- NA_character_
  if (grepl("^FOR ", text)) in_house <- grepl("^FOR UNITED STATES REPRESENTATIVE", text)
  if (grepl("^Recapitulation|^SPECIAL ELECTION", text)) in_house <- FALSE
  if (!in_house || is.na(state)) next
  if (grepl("^[0-9]+\\. ", text)) {
    district <- as.integer(sub("^([0-9]+)\\..*", "\\1", text))
    text <- sub("^[0-9]+\\. ", "", text)
  }
  if (!grepl("\\.{3,}.*([0-9]|\\(1\\))$", text)) next
  unopposed <- grepl("\\(1\\)$", text)
  votes <- if (unopposed) NA_real_ else as.numeric(gsub(",", "", sub(".*?([0-9][0-9,]*)$", "\\1", text)))
  label <- trimws(sub("\\.{3,}.*", "", text))
  if (grepl(",", label, fixed = TRUE)) {
    # Party names follow the last comma before the affiliation; names may contain commas.
    party <- if (grepl(", (Democrat|Democratic|Democratic-Farmer-Labor)(,|$)", label)) "D" else if (grepl(", Republican(,|$)", label)) "R" else "O"
    rows[[length(rows) + 1L]] <- data.frame(district_id = sprintf("%s-%02d", state, district),
      candidate = label, party = party, votes = votes)
    last_candidate <- length(rows)
  } else if (state %in% c("NY", "CT") && !grepl("^(Blank|Scattering|Void|Write-in|Total)", label) && !is.na(last_candidate)) {
    # Fusion ballot lines belong to the preceding candidate, not a second candidate.
    rows[[last_candidate]]$votes <- rows[[last_candidate]]$votes + votes
  }
}
candidates <- do.call(rbind, rows)
# A subsequent special-election section must never overwrite November's results.
stopifnot(!anyDuplicated(paste(candidates$district_id, candidates$candidate)))
baseline <- do.call(rbind, lapply(split(candidates, candidates$district_id), function(x) {
  d <- sum(x$votes[x$party == "D"], na.rm = TRUE)
  r <- sum(x$votes[x$party == "R"], na.rm = TRUE)
  unopposed <- nrow(x) == 1 && is.na(x$votes[1])
  data.frame(district_id = x$district_id[1], state = substr(x$district_id[1], 1, 2),
    d_votes = if (unopposed) NA else d, r_votes = if (unopposed) NA else r,
    d_share_2024 = if (unopposed) as.numeric(x$party[1] == "D") else d / (d + r),
    winner_2024 = if (unopposed) x$party[1] else x$party[which.max(x$votes)], contested = d > 0 && r > 0,
    boundary_changed = substr(x$district_id[1], 1, 2) %in% changed_states)
}))
rownames(baseline) <- NULL
stopifnot(nrow(baseline) == 435L, sum(baseline$winner_2024 == "D") == 215L,
          sum(baseline$winner_2024 == "R") == 220L, all(is.finite(baseline$d_share_2024)))
write.csv(baseline, "data/house_2024.csv", row.names = FALSE, na = "")
write.csv(candidates, "data/raw/house_2024_candidates.csv", row.names = FALSE)
cat("Wrote", nrow(baseline), "districts; D 215, R 220.\n")
