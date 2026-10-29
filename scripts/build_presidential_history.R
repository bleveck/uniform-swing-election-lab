# A separate empirical prior: midterm House D share minus preceding presidential
# D share. All shares are TWO-PARTY; no House-to-House prior is substituted.
source("R/bayes.R")
chronology <- read.csv("data/historical_midterms.csv")
j <- read.delim("data/raw/jacobson_JOPrepfile1.tab")
j <- j[which(is.finite(j$year) & j$year >= 1946 & j$year <= 2014 & j$year %% 4 == 2), ]
state_index <- as.integer(j$stcd %/% 100)
stopifnot(all(state_index %in% 1:50))
old <- data.frame(year = j$year, state = tolower(state.name[state_index]), district = as.integer(j$stcd %% 100),
  d_share_previous = j$dpres / 100, d_share_current = j$dv / 100,
  redist = j$redist, source_current = "Gary Jacobson, JOP aggregate replication data",
  source_baseline = "Jacobson dpres: major-party presidential share, two years earlier")

# The existing audit preserves current 2018 shares even for pairs excluded from
# the House-to-House calculation. A contested 2016 HOUSE race is not required.
all_pairs <- read.csv("data/historical_pair_audit.csv")
recent <- all_pairs[all_pairs$year == 2018, c("year", "state", "district", "d_share_current")]
stopifnot(nrow(recent) == 435L)
recent_id <- paste0(state.abb[match(recent$state, tolower(state.name))], "-", sprintf("%02d", pmax(1L, recent$district)))
e <- new.env(); load("data/raw/cces_cd_info_2018.rda", envir = e)
p <- e$cd_info_2018
stopifnot(nrow(p) == 435L, !anyDuplicated(p$cd), setequal(recent_id, p$cd))
recent$d_share_previous <- 1 - p$pct_trump[match(recent_id, p$cd)]
recent$redist <- NA_integer_ # No Jacobson flag; the presidential vote is explicitly on the 2018 map.
recent$source_current <- "MIT Election Lab 2018 House, from saved current-share audit"
recent$source_baseline <- "The Downballot / ccesMRPprep: 2016 president on 2018 lines"
x <- rbind(old, recent[, names(old)])
stopifnot(!anyDuplicated(paste(x$year, x$state, x$district)))
x$reason <- "Included"
x$reason[!is.finite(x$d_share_previous)] <- "Presidential district share unavailable"
x$reason[!is.finite(x$d_share_current) | x$d_share_current <= 0 | x$d_share_current >= 1] <- "House not contested by both major parties"
x$reason[is.finite(x$redist) & x$redist == 1] <- "Jacobson flags redrawn district"
x$reason[x$year %% 10 == 2] <- "Post-census redistricting cycle"
x$d_swing_pp <- 100 * (x$d_share_current - x$d_share_previous)
party <- chronology$president_party[match(x$year, chronology$year)]
x$against_president_pp <- ifelse(party == "R", x$d_swing_pp, -x$d_swing_pp)
x$included <- x$reason == "Included"
x$reference_type <- "president"
x$reference_year <- x$year - 2L
h <- chronology[, c("year", "baseline_year", "president", "president_party", "included", "exclusion", "n_districts", "d_swing_pp", "against_president_pp", "district_sd_pp")]
for (i in seq_len(nrow(h))) {
  z <- x[x$year == h$year[i] & x$included, ]
  h$n_districts[i] <- nrow(z)
  h$included[i] <- nrow(z) >= 2 && h$year[i] %% 10 != 2
  h$exclusion[i] <- if (h$year[i] %% 10 == 2) "Post-census redistricting cycle" else if (!nrow(z)) "Presidential district shares unavailable" else ""
  h$d_swing_pp[i] <- if (nrow(z)) mean(z$d_swing_pp) else NA_real_
  h$against_president_pp[i] <- if (nrow(z)) mean(z$against_president_pp) else NA_real_
  h$district_sd_pp[i] <- if (nrow(z) > 1) sd(z$d_swing_pp) else NA_real_
}
stopifnot(sum(h$included) == 14L, min(h$year[h$included]) == 1954, max(h$year[h$included]) == 2018)
write.csv(x, "data/historical_president_pair_audit.csv", row.names = FALSE, na = "")
write.csv(h, "data/historical_president_midterms.csv", row.names = FALSE, na = "")
prior <- fit_midterm_prior(h, "R")
write.csv(as.data.frame(prior), "data/historical_president_prior.csv", row.names = FALSE)
print(h[, c("year", "included", "n_districts", "against_president_pp")], row.names = FALSE)
cat(sprintf("House-minus-president prior: Normal(%+.3f, %.3f^2) pp; district SD %.3f pp.\n", prior$mean_pp, prior$sd_pp, prior$district_sd_pp))
