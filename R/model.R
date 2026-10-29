# All swings are percentage points of Democratic TWO-PARTY VOTE SHARE.
# A +3 pp share swing is a +6 pp D-minus-R margin swing.
changed_states <- c("AL", "CA", "FL", "LA", "NC", "OH", "TN", "TX", "UT")
watch_districts <- c("KY-06", "VA-01", "VA-02", "VA-05", "NC-01", "NC-11", "OH-07", "OH-09", "OH-10", "OH-15")

project_house <- function(baseline, swing_pp) {
  stopifnot(length(swing_pp) == 1L, is.finite(swing_pp))
  x <- baseline
  x$projected_d_share <- pmin(1, pmax(0, x$d_share_2024 + swing_pp / 100))
  # No imputation of a hypothetical opponent in one-party or same-party contests.
  x$projected_d_share[!x$contested] <- x$d_share_2024[!x$contested]
  x$projected_party <- ifelse(!x$contested, x$winner_2024,
    ifelse(abs(x$projected_d_share - .5) < 1e-10, "Tie", ifelse(x$projected_d_share > .5, "D", "R")))
  x$flipped <- x$projected_party != x$winner_2024 & x$projected_party != "Tie"
  x
}

estimate_swing <- function(baseline, results, min_votes = 1000, live = FALSE, exclude = character()) {
  x <- merge(baseline, results, by = "district_id", all.x = TRUE, sort = FALSE)
  x$two_party_votes <- x$d_votes_current + x$r_votes_current
  x$current_d_share <- ifelse(x$two_party_votes > 0, x$d_votes_current / x$two_party_votes, NA_real_)
  x$swing_pp <- 100 * (x$current_d_share - x$d_share_2024)
  x$reason <- "Included"
  x$reason[!x$contested] <- "One-party 2024 contest"
  if (live) x$reason[x$boundary_changed] <- "Changed boundaries: matched baseline needed"
  x$reason[x$district_id %in% exclude] <- "Excluded by user"
  x$reason[!is.na(x$two_party_votes) & x$two_party_votes < min_votes] <- "Below vote threshold"
  x$reason[is.na(x$two_party_votes) | x$two_party_votes == 0] <- "Awaiting votes"
  if ("is_test" %in% names(x)) x$reason[!is.na(x$is_test) & x$is_test] <- "Provider test data"
  x$included <- x$reason == "Included" & is.finite(x$swing_pp)
  used <- x[x$included, , drop = FALSE]
  list(swing_pp = if (nrow(used)) mean(used$swing_pp) else NA_real_,
       n = nrow(used), districts = x, used = used)
}

seat_counts <- function(projection) {
  setNames(vapply(c("D", "R", "Tie"), function(p) sum(projection$projected_party == p), integer(1)), c("D", "R", "Tie"))
}
