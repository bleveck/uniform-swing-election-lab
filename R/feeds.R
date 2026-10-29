# Public feeds: fetch cumulative snapshots; NEVER add successive snapshots.
source("R/results.R")

download_public <- function(url, extension = "") {
  path <- tempfile(fileext = extension)
  req <- httr2::request(url) |>
    httr2::req_user_agent("uniform-swing-classroom-demo/0.1") |>
    httr2::req_timeout(20)
  response <- httr2::req_perform(req, path = path)
  list(path = path, updated = httr2::resp_header(response, "last-modified") %||% NA_character_)
}

parse_nc <- function(path, expected_date = "2026-11-03") {
  if (grepl("\\.zip$", path, ignore.case = TRUE)) {
    files <- unzip(path, list = TRUE)$Name
    file <- files[grepl("^results_pct_[0-9]+\\.txt$", files)]
    if (length(file) != 1) stop("Unexpected NC ZIP contents.")
    con <- unz(path, file, open = "r")
    on.exit(close(con))
  } else con <- path
  x <- read.delim(con, check.names = FALSE, quote = "", stringsAsFactors = FALSE, fill = TRUE)
  needed <- c("County", "Precinct", "Contest Name", "Choice", "Choice Party", "Total Votes", "Election Date")
  if (!all(needed %in% names(x))) stop("NC schema changed: required columns missing.")
  house <- grepl("^US HOUSE OF REPRESENTATIVES DISTRICT [0-9]+$", trimws(x[["Contest Name"]]))
  x <- x[house, , drop = FALSE]
  if (!nrow(x)) stop("No NC House contests found.")
  if (any(as.Date(x[["Election Date"]], "%m/%d/%Y") != as.Date(expected_date))) stop("Wrong NC election date.")
  # The documented precinct file contains disjoint precinct/method records;
  # use Total Votes only, never Total Votes plus its component methods.
  key <- do.call(paste, c(x[c("County", "Precinct", "Contest Name", "Choice")], sep = "|"))
  if (anyDuplicated(key)) stop("Duplicate NC precinct/candidate rows.")
  x$id <- sprintf("NC-%02d", as.integer(sub(".*DISTRICT ", "", x[["Contest Name"]])))
  rows <- lapply(split(x, x$id), function(d) {
    party <- trimws(d[["Choice Party"]])
    if (!all(c("DEM", "REP") %in% party)) stop("NC contest lacks both major-party candidates.")
    data.frame(district_id = d$id[1], d_votes_current = sum(d[["Total Votes"]][party == "DEM"]),
      r_votes_current = sum(d[["Total Votes"]][party == "REP"]), election_date = expected_date)
  })
  out <- do.call(rbind, rows); out$source <- "NC SBE precinct ZIP"
  validate_results(out, expected_date)
}

parse_va <- function(path, expected_date = "2026-11-03") {
  x <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(x$electionDate, expected_date)) stop("Wrong Virginia election date.")
  # Only the statewide ballotItems: child locality and precinct totals would double count.
  contests <- x$results$ballotItems
  contests <- Filter(function(c) grepl("^Member, House of Representatives \\([0-9]+(st|nd|rd|th) District\\)$", c$name), contests)
  if (!length(contests)) stop("No Virginia House contests found; export schema may have changed.")
  rows <- lapply(contests, function(c) {
    party <- vapply(c$ballotOptions, function(z) z$politicalParty %||% "", character(1))
    votes <- vapply(c$ballotOptions, function(z) as.numeric(z$voteCount), numeric(1))
    if (!all(c("Democratic", "Republican") %in% party)) stop("VA contest lacks both major-party candidates.")
    data.frame(district_id = sprintf("VA-%02d", as.integer(sub(".*\\(([0-9]+).*", "\\1", c$name))),
      d_votes_current = sum(votes[party == "Democratic"]), r_votes_current = sum(votes[party == "Republican"]),
      election_date = expected_date)
  })
  out <- do.call(rbind, rows); out$source <- "VA ELECT media JSON"
  out$source_updated_at <- x$createdAt %||% NA_character_
  out$is_test <- isTRUE(x$isTest)
  validate_results(out, expected_date)
}

parse_oh <- function(path, expected_date = "2026-11-03") {
  doc <- xml2::read_xml(path)
  ns <- c(n = "http://grouper.ieee.org/groups/1622/groups/2/V1/1622_2-election_results_reporting.xsd")
  if (xml2::xml_attr(xml2::xml_find_first(doc, ".//n:Election", ns), "Date") != expected_date) stop("Wrong Ohio election date.")
  parties <- xml2::xml_find_all(doc, ".//n:PartyCollection/n:Party", ns)
  party_lookup <- setNames(xml2::xml_attr(parties, "Abbreviation"), xml2::xml_attr(parties, "ObjectId"))
  candidates <- xml2::xml_find_all(doc, ".//n:CandidateCollection/n:Candidate", ns)
  candidate_party <- setNames(party_lookup[xml2::xml_text(xml2::xml_find_first(candidates, "./n:PartyId", ns))], xml2::xml_attr(candidates, "ObjectId"))
  units <- xml2::xml_find_all(doc, ".//n:GpUnitCollection/n:GpUnit", ns)
  unit_type <- setNames(xml2::xml_attr(units, "Type"), xml2::xml_attr(units, "ObjectId"))
  contests <- xml2::xml_find_all(doc, ".//n:ContestCollection/n:Contest[starts-with(@Name, 'Representative to Congress - District ')]", ns)
  if (!length(contests)) stop("No Ohio House contests found; XML schema may have changed.")
  rows <- lapply(contests, function(c) {
    selections <- xml2::xml_find_all(c, "./n:BallotSelection", ns)
    party <- candidate_party[xml2::xml_text(xml2::xml_find_first(selections, "./n:CandidateId", ns))]
    votes <- vapply(selections, function(s) {
      counts <- xml2::xml_find_all(s, "./n:VoteCountsCollection/n:VoteCounts[@Type='Total']", ns)
      ids <- xml2::xml_text(xml2::xml_find_first(counts, "./n:GpUnitId", ns))
      # This feed publishes district summary AND county components. Select district
      # summaries when available; summing all Total nodes would count votes twice.
      types <- unname(unit_type[ids])
      chosen <- if (any(types == "Congressional", na.rm = TRUE)) types == "Congressional" else types == "County"
      selected <- counts[which(chosen)]
      if (length(selected) == 0 || anyDuplicated(ids[which(chosen)])) stop("Unexpected Ohio reporting units.")
      sum(as.numeric(xml2::xml_attr(selected, "Count")))
    }, numeric(1))
    if (!all(c("DEM", "REP") %in% party)) stop("OH contest lacks both major-party candidates.")
    data.frame(district_id = sprintf("OH-%02d", as.integer(sub(".*District ", "", xml2::xml_attr(c, "Name")))),
      d_votes_current = sum(votes[which(party == "DEM")]), r_votes_current = sum(votes[which(party == "REP")]),
      election_date = expected_date)
  })
  out <- do.call(rbind, rows); out$source <- "OH SOS XML"
  out$source_updated_at <- xml2::xml_attr(doc, "GeneratedDate")
  out$is_test <- tolower(xml2::xml_attr(doc, "IsTest")) == "true"
  if (anyNA(out$is_test)) stop("Ohio feed missing test-data flag.")
  validate_results(out, expected_date)
}

feed_config <- list(
  VA = list(url = "https://enr.elections.virginia.gov/cdn/results/virginia/export-2026-November-General.json", ext = ".json", parser = parse_va),
  NC = list(url = "https://dl.ncsbe.gov/ENRS/2026_11_03/results_pct_20261103.zip", ext = ".zip", parser = parse_nc),
  OH = list(url = "https://liveresults.ohiosos.gov/Api/v1/download?filename=VSSC1622XmlFileBlob", ext = ".xml", parser = parse_oh))

fetch_feed <- function(state) {
  config <- feed_config[[state]]
  download <- download_public(config$url, config$ext)
  on.exit(unlink(download$path))
  results <- config$parser(download$path)
  if (all(is.na(results$source_updated_at))) results$source_updated_at <- download$updated
  # No provider's pre-election test/preparation totals may become observations.
  if (Sys.time() < as.POSIXct("2026-11-03 18:00:00", tz = "America/New_York")) results$is_test <- TRUE
  results[results$district_id %in% watch_districts, , drop = FALSE]
}
