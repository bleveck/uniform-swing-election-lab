# Rebuild the empirical prior from saved, public district returns.
# All quantities are pp of TWO-PARTY SHARE, never D-minus-R margin or seats.
wolf <- read.csv("data/raw/wolf_house_1896_2014.csv")
medsl <- read.csv("data/raw/medsl_house_1976_2018.csv", stringsAsFactors = FALSE, fileEncoding = "latin1")
vintages <- read.csv("data/raw/boundary_vintages.csv", stringsAsFactors = FALSE)

# Use one return source within each election pair: Wolf through 2014, then
# MEDSL for BOTH 2016 and 2018. No source discontinuity enters a paired swing.
old <- data.frame(year = as.integer(wolf$year), state = tolower(wolf$name),
  district = as.integer(wolf$lewis_dist), d_share = wolf$vote_share,
  source = "Wolf / King / CLEA")
old <- old[old$year >= 1944 & old$year <= 2014, ]
new <- medsl[medsl$year %in% c(2016, 2018) & medsl$stage == "gen" &
  !medsl$special & !(medsl$runoff %in% TRUE) & medsl$mode == "total", ]
new <- new[new$state_po %in% state.abb, ]
new$candidate_key <- paste(new$year, new$state_fips, new$district, toupper(trimws(new$candidate)))
new$major <- ifelse(new$party == "democrat", "D", ifelse(new$party == "republican", "R", NA_character_))
endorsed <- unique(new[!is.na(new$major), c("candidate_key", "major")])
stopifnot(!anyDuplicated(endorsed$candidate_key))
# Credit additional fusion ballot lines to the same endorsed candidate.
new$major <- endorsed$major[match(new$candidate_key, endorsed$candidate_key)]
new$key <- paste(new$year, new$state_fips, new$district)
recent <- do.call(rbind, lapply(split(new, new$key), function(x) {
  d <- sum(x$candidatevotes[which(x$major == "D")])
  r <- sum(x$candidatevotes[which(x$major == "R")])
  data.frame(year = x$year[1], state = tolower(x$state[1]),
    district = if (sum(state.abb == x$state_po[1]) && x$state_po[1] %in% c("AK", "DE", "MT", "ND", "SD", "VT", "WY")) 0L else x$district[1],
    d_share = d / (d + r), source = "MIT Election Lab 1976–2018")
}))
returns <- rbind(old, recent)
returns <- returns[returns$state %in% tolower(state.name), ]
# Multi-seat at-large contests can collapse to the same geographic ID in Wolf.
# They cannot be paired unambiguously and are excluded rather than averaged.
returns$key <- paste(returns$year, returns$state, returns$district)
returns$ambiguous <- duplicated(returns$key) | duplicated(returns$key, fromLast = TRUE)

years <- seq(1946, 2022, 4)
president <- c("Truman", "Truman", "Eisenhower", "Eisenhower", "Kennedy", "Johnson", "Nixon", "Ford", "Carter", "Reagan", "Reagan", "G. H. W. Bush", "Clinton", "Clinton", "G. W. Bush", "G. W. Bush", "Obama", "Obama", "Trump", "Biden")
party <- c("D", "D", "R", "R", "D", "D", "R", "R", "D", "R", "R", "R", "D", "D", "R", "R", "D", "D", "R", "D")
summaries <- audits <- list()
vintages$state <- tolower(vintages$state_name)
for (i in seq_along(years)) {
  year <- years[i]
  decennial <- year %% 10 == 2
  summary <- data.frame(year = year, baseline_year = year - 2, president = president[i], president_party = party[i],
    included = !decennial, exclusion = if (decennial) "Post-census redistricting cycle" else "",
    n_districts = 0L, n_changed_state_pairs = 0L, changed_states = "", d_swing_pp = NA_real_,
    against_president_pp = NA_real_, district_sd_pp = NA_real_)
  if (decennial) { summaries[[i]] <- summary; next }
  current <- returns[returns$year == year, ]
  previous <- returns[returns$year == year - 2, ]
  stopifnot(nrow(current) > 400, nrow(previous) > 400)
  x <- merge(current, previous, by = c("state", "district"), suffixes = c("_current", "_previous"))
  x$year <- year
  x$reason <- "Included"
  x$reason[!is.finite(x$d_share_current) | !is.finite(x$d_share_previous)] <- "Missing share"
  x$reason[is.finite(x$d_share_current) & is.finite(x$d_share_previous) &
    (x$d_share_current <= 0 | x$d_share_current >= 1 | x$d_share_previous <= 0 | x$d_share_previous >= 1)] <- "Not contested by both major parties in both elections"
  x$reason[x$ambiguous_current | x$ambiguous_previous] <- "Ambiguous multi-seat at-large ID"
  congress <- (year - 1788) / 2 + 1
  # Any new boundary vintage in a state is a conservative state-level exclusion.
  # Vintages can also change for mapping revisions, so some unchanged districts
  # are deliberately excluded. Decennial years are excluded in their entirety.
  changed <- intersect(unique(vintages$state[vintages$start_congress == congress]), tolower(state.name))
  x$reason[x$state %in% changed] <- "New boundary vintage in state"
  # Fail closed if the archive cannot place a state in a known boundary vintage.
  covered <- unique(vintages$state[vintages$start_congress <= congress - 1 & vintages$end_congress >= congress])
  x$reason[!x$state %in% c(covered, changed)] <- "Boundary continuity unverified"
  x$d_swing_pp <- 100 * (x$d_share_current - x$d_share_previous)
  x$against_president_pp <- if (party[i] == "R") x$d_swing_pp else -x$d_swing_pp
  x$included <- x$reason == "Included"
  used <- x[x$included, ]
  stopifnot(nrow(used) >= 100, all(is.finite(used$against_president_pp)))
  summary$n_districts <- nrow(used)
  summary$n_changed_state_pairs <- sum(x$state %in% changed)
  summary$changed_states <- paste(sort(changed), collapse = "; ")
  summary$d_swing_pp <- mean(used$d_swing_pp)
  summary$against_president_pp <- mean(used$against_president_pp)
  summary$district_sd_pp <- sd(used$d_swing_pp)
  summaries[[i]] <- summary
  audits[[i]] <- x[, c("year", "state", "district", "d_share_previous", "d_share_current", "d_swing_pp", "against_president_pp", "included", "reason", "source_current")]
}
history <- do.call(rbind, summaries)
audit <- do.call(rbind, audits)
stopifnot(sum(history$included) == 16L, min(history$year[history$included]) == 1946,
  max(history$year[history$included]) == 2018, all(!history$included[history$year %% 10 == 2]))
write.csv(history, "data/historical_midterms.csv", row.names = FALSE, na = "")
write.csv(audit, "data/historical_pair_audit.csv", row.names = FALSE, na = "")
source("R/bayes.R")
prior <- fit_midterm_prior(history, "R")
write.csv(as.data.frame(prior), "data/historical_prior.csv", row.names = FALSE)
print(history[, c("year", "president_party", "included", "n_districts", "against_president_pp")], row.names = FALSE)
cat(sprintf("2026 D-share prior: Normal(%+.3f, %.3f^2) pp; pooled district SD %.3f pp.\n", prior$mean_pp, prior$sd_pp, prior$district_sd_pp))
