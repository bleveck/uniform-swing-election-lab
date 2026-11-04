# Laptop-only reader for cumulative statewide House results in public AP widgets.
parse_ap_house <- function(summary_path, metadata_path, config, now = Sys.time()) {
  s <- jsonlite::fromJSON(summary_path, simplifyVector = FALSE)
  m <- jsonlite::fromJSON(metadata_path, simplifyVector = FALSE)
  if (!identical(s$raceID, config$race_id) ||
      !identical(m$raceID, config$race_id) ||
      !identical(m$electionDate, "2026-11-03") ||
      !identical(m$eventID, "20261103") ||
      !identical(m$raceTypeID, "G") || !identical(m$officeID, "H") ||
      !identical(m$statePostal, config$state) || !identical(m$seatNum, config$seat) ||
      !identical(s$statePostal, config$state) || !identical(s$level, "state") ||
      !identical(as.integer(s$reportingunitLevel), 1L)) {
    stop("AP metadata must identify the November 3, 2026 ", config$district_id, " general House race and statewide totals.")
  }
  if (!is.logical(s$test) || length(s$test) != 1L || is.na(s$test) ||
      !is.character(s$resultsType) || length(s$resultsType) != 1L ||
      !s$resultsType %in% c("live", "test") ||
      (!s$test && s$resultsType != "live")) stop("Missing or invalid AP live/test status.")
  stamp <- s$lastUpdated
  if (!is.character(stamp) || length(stamp) != 1L || is.na(stamp) ||
      !grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.[0-9]+)?Z$", stamp)) {
    stop("Invalid AP publication timestamp.")
  }
  updated <- as.POSIXct(strptime(stamp, "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  if (is.na(updated) || updated > now + 300) stop("Invalid or future AP publication timestamp.")
  candidates <- s$candidates
  metadata <- m$candidates
  if (!is.list(candidates) || !length(candidates) || !is.list(metadata) || !length(metadata)) {
    stop("AP candidate records are missing.")
  }
  ids <- vapply(candidates, function(x) {
    id <- x$candidateID
    if (!is.character(id) || length(id) != 1L || is.na(id) || !nzchar(id)) stop("Invalid AP candidate ID.")
    id
  }, character(1))
  if (anyDuplicated(ids) || any(!ids %in% names(metadata))) stop("Duplicate or unknown AP candidate ID.")
  parties <- vapply(ids, function(id) {
    candidate <- metadata[[id]]
    if (!identical(candidate$candidateID, id) || !is.character(candidate$party) ||
        length(candidate$party) != 1L || is.na(candidate$party)) stop("Invalid AP candidate party metadata.")
    toupper(candidate$party)
  }, character(1))
  if (sum(parties == "DEM") != 1L || sum(parties == "GOP") != 1L) {
    stop("AP race must contain exactly one Democratic and one Republican candidate.")
  }
  votes <- vapply(candidates, function(x) {
    v <- x$voteCount
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 0 || v != floor(v)) {
      stop("AP vote counts must be finite, nonnegative whole numbers.")
    }
    as.numeric(v)
  }, numeric(1))
  opening <- as.POSIXct(config$opening, tz = "UTC")
  validate_results(data.frame(district_id = config$district_id,
    d_votes_current = unname(votes[parties == "DEM"]),
    r_votes_current = unname(votes[parties == "GOP"]), election_date = "2026-11-03",
    source = config$source,
    fetched_at = format(now, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    source_updated_at = format(updated, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    is_test = s$test || updated < opening || now < opening))
}

fetch_ap_house <- function(config, now = Sys.time(), download = download_public) {
  paths <- character()
  on.exit(unlink(paths))
  for (file in c("metadata", "summary")) {
    result <- download(paste0(config$base, file, ".json"), ".json")
    paths[file] <- result$path
  }
  parse_ap_house(paths[["summary"]], paths[["metadata"]], config, now)
}
