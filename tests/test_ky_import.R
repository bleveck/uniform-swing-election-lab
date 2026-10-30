source("scripts/ky_import_functions.R")

test_that("authentic 2026 preparation excerpts import with namespaces and named unit types", {
  folder <- tempfile(); dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  files <- list.files("data/fixtures/ky_2026_v6", pattern = "\\.xml$", full.names = TRUE)
  expect_equal(length(files), 6L)
  file.copy(files, folder)
  Sys.setFileTime(file.path(folder, "CurrentResultsExcludeLocal.xml"), collector_time("2026-10-30T22:14:02Z"))
  x <- read_ky_downloads(folder, collector_time("2026-11-04T00:00:00Z"))
  expect_identical(x$results$district_id, "KY-06")
  expect_equal(x$results$d_votes_current, 0)
  expect_equal(x$results$r_votes_current, 0)
  expect_true(x$results$is_test) # saved preparation files stay excluded later
  expect_identical(x$selected_units$UnitId, "2")
  expect_setequal(x$candidates$major, c("D", "R"))
})

# Synthetic v6 XML records exercising the documented schema, not real returns.
ky_fixture <- function(folder, level = "all", stamp = "2026-11-03T23:30:00Z") {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  table_xml <- function(file, root, record, rows) {
    body <- vapply(seq_len(nrow(rows)), function(i) paste0("<", record, ">",
      paste0("<", names(rows), ">", as.character(rows[i, ]), "</", names(rows), ">", collapse = ""),
      "</", record, ">"), character(1))
    writeLines(paste0("<", root, ' xmlns="http://schemas.datacontract.org/2004/07/SBE.ENR.Web.Public.Wrappers">',
      paste(body, collapse = ""), "</", root, ">"), file.path(folder, file))
  }
  table_xml("elections.xml", "ArrayOfElection", "Election", data.frame(
    ElectionDate = "2026-11-03T00:00:00", ElectionName = "2026 General Election", ElectionType = "General"))
  table_xml("parties.xml", "ArrayOfPoliticalParty", "PoliticalParty", data.frame(
    PartyId = c("1", "2", "3"), Abbreviation = c("DEM", "REP", "LIB"),
    PartyName = c("Democratic", "Republican", "Libertarian")))
  table_xml("contests.xml", "ArrayOfContest", "Contest", data.frame(
    ContestId = c("6", "106", "26"), ContestName = c("US Representative - 6th District", "State Representative - 6th District", "US Representative - 2nd District"),
    ContestScopeUnitId = "2"))
  table_xml("candidates.xml", "ArrayOfCandidate", "Candidate", data.frame(
    CandidateId = c("10", "11", "12", "13"), ContestId = "6", BallotName = c("Example Democrat", "Example Republican", "Example Libertarian", "Write-in"),
    PoliticalPartyId = c("1", "2", "3", "0"), IsWriteIn = c("false", "false", "false", "true"), IsWithdrawn = "false"))
  table_xml("units.xml", "ArrayOfGeopoliticalUnit", "GeopoliticalUnit", data.frame(
    UnitId = c("1", "2", "3", "4", "31", "41"), ParentId = c("", "1", "2", "2", "3", "4"),
    UnitName = c("United States", "Kentucky", "County A", "County B", "Precinct A", "Precinct B"),
    UnitType = c("Country", "State", "County", "County", "Precinct", "Precinct")))
  units <- switch(level, all = c("2", "3", "4", "31", "41"),
    counties = c("3", "4", "31", "41"), mixed = c("3", "31", "41"), precincts = c("31", "41"))
  rows <- do.call(rbind, lapply(units, function(id) {
    votes <- if (id == "2") c(3000, 4000) else if (id %in% c("3", "31")) c(1000, 1500) else c(2000, 2500)
    data.frame(ContestId = "6", CandidateId = c("10", "11"), ReportingUnitId = id,
      TotalVotes = votes, ElectionDayVotes = votes - 100)
  }))
  rows <- rbind(rows, data.frame(ContestId = "6", CandidateId = "13", ReportingUnitId = "2", TotalVotes = 25, ElectionDayVotes = 25))
  table_xml("current.xml", "CandidateData", "CandidateData", rows)
  file <- file.path(folder, "current.xml")
  text <- readLines(file)
  writeLines(paste0('<SummaryReport xmlns="http://schemas.datacontract.org/2004/07/SBE.ENR.Web.Public.Wrappers">',
    text, "</SummaryReport>"), file)
  Sys.setFileTime(file.path(folder, "current.xml"), collector_time(stamp))
  invisible(folder)
}

test_that("Kentucky summaries and their components are never counted together", {
  folder <- tempfile(); on.exit(unlink(folder, recursive = TRUE))
  for (level in c("all", "counties", "mixed", "precincts")) {
    ky_fixture(folder, level)
    x <- read_ky_downloads(folder, collector_time("2026-11-04T00:00:00Z"))
    expect_equal(x$results$d_votes_current, 3000)
    expect_equal(x$results$r_votes_current, 4000)
    expect_equal(nrow(x$selected_units), if (level == "all") 1L else 2L)
    expect_identical(x$results$district_id, "KY-06")
    expect_false(x$results$is_test)
    unlink(folder, recursive = TRUE)
  }
})

test_that("Kentucky validates election metadata and refuses incomplete/bad downloads", {
  folder <- tempfile(); on.exit(unlink(folder, recursive = TRUE))
  ky_fixture(folder)
  clock <- collector_time("2026-11-04T00:00:00Z")
  change <- function(file, old, new) {
    path <- file.path(folder, file)
    writeLines(gsub(old, new, paste(readLines(path), collapse = ""), fixed = TRUE), path)
  }
  change("elections.xml", "2026-11-03", "2026-05-19")
  expect_error(read_ky_downloads(folder, clock), "Expected metadata")
  ky_fixture(folder)
  unlink(file.path(folder, "parties.xml"))
  expect_error(read_ky_downloads(folder, clock), "Missing Kentucky XML datasets: parties")
  ky_fixture(folder)
  change("contests.xml", "US Representative - 6th District", "State Representative - 6th District")
  expect_error(read_ky_downloads(folder, clock), "exactly one U.S. House")
  ky_fixture(folder)
  change("candidates.xml", "<PoliticalPartyId>2</PoliticalPartyId>", "<PoliticalPartyId>3</PoliticalPartyId>")
  expect_error(read_ky_downloads(folder, clock), "one non-write-in")
  ky_fixture(folder)
  change("current.xml", "<TotalVotes>3000</TotalVotes>", "<TotalVotes>-3000</TotalVotes>")
  expect_error(read_ky_downloads(folder, clock), "Invalid Kentucky vote")
  ky_fixture(folder)
  change("current.xml", "<ReportingUnitId>4</ReportingUnitId>", "<ReportingUnitId>3</ReportingUnitId>")
  expect_error(read_ky_downloads(folder, clock), "Duplicate Kentucky")
  ky_fixture(folder)
  change("current.xml", "<ReportingUnitId>2</ReportingUnitId>", "<ReportingUnitId>999</ReportingUnitId>")
  expect_error(read_ky_downloads(folder, clock), "unknown Kentucky reporting")
  ky_fixture(folder)
  change("current.xml", "<CandidateId>11</CandidateId>", "<CandidateId>12</CandidateId>")
  expect_error(read_ky_downloads(folder, clock), "lacks one major-party")
  ky_fixture(folder)
  change("current.xml", "ReportingUnitId", "gpu_id")
  expect_error(read_ky_downloads(folder, clock), "2026 v6")
  ky_fixture(folder)
  writeLines("<html><body>Access blocked</body></html>", file.path(folder, "blocked.xml"))
  expect_error(read_ky_downloads(folder, clock), "web/error page")
})

test_that("manual XML import preserves time, test flags, and last good CSV on failure", {
  folder <- tempfile(); output <- tempfile(fileext = ".csv")
  on.exit({unlink(folder, recursive = TRUE); unlink(output)})
  clock <- collector_time("2026-11-04T00:00:00Z")
  ky_fixture(folder)
  x <- import_ky_downloads(folder, output, clock)
  expect_equal(read.csv(output)$d_votes_current, 3000)
  expect_equal(collector_stamp(file.info(output)$mtime), "2026-11-03T23:30:00Z")
  expect_identical(read.csv(output)$source, "KY SOS manually downloaded XML")
  import_ky_downloads(folder, output, clock + 3600)
  expect_equal(collector_stamp(file.info(output)$mtime), "2026-11-03T23:30:00Z")
  before <- tools::md5sum(output)
  ky_fixture(folder, stamp = "2026-11-03T23:00:00Z")
  expect_error(import_ky_downloads(folder, output, clock), "older/undated")
  expect_identical(tools::md5sum(output), before)
  ky_fixture(folder, stamp = "2026-11-03T22:59:00Z")
  expect_true(read_ky_downloads(folder, clock)$results$is_test)
  ky_fixture(folder)
  path <- file.path(folder, "current.xml")
  text <- readLines(path)
  writeLines(sub("<SummaryReport ", '<SummaryReport IsTest="true" ', text, fixed = TRUE), path)
  Sys.setFileTime(path, collector_time("2026-11-03T23:30:00Z"))
  expect_true(read_ky_downloads(folder, clock)$results$is_test)
  expect_true(read_ky_downloads(folder, clock, force_test = TRUE)$results$is_test)
  ky_fixture(folder, stamp = "2026-11-04T00:10:00Z")
  expect_error(read_ky_downloads(folder, clock), "future download")
})

test_that("newest manual result file is selected and ambiguous copies fail closed", {
  folder <- tempfile(); on.exit(unlink(folder, recursive = TRUE))
  ky_fixture(folder)
  old <- file.path(folder, "current.xml")
  newer <- file.path(folder, "CurrentResultsExcludeLocal (1).xml")
  file.copy(old, newer)
  text <- readLines(newer)
  writeLines(sub("<TotalVotes>3000</TotalVotes>", "<TotalVotes>3500</TotalVotes>", text, fixed = TRUE), newer)
  stamp <- collector_time("2026-11-03T23:40:00Z")
  Sys.setFileTime(newer, stamp)
  expect_equal(read_ky_downloads(folder, stamp)$results$d_votes_current, 3500)
  Sys.setFileTime(old, stamp)
  expect_error(read_ky_downloads(folder, stamp), "share the newest")
})

test_that("collector imports Kentucky locally and retains it when subsequent files fail", {
  folder <- tempfile(); old <- getwd(); workspace <- tempfile()
  dir.create(workspace)
  on.exit({setwd(old); unlink(c(folder, workspace), recursive = TRUE)})
  ky_fixture(folder)
  # Run from a disposable workspace with only the baseline needed by validation.
  dir.create(file.path(workspace, "data"))
  file.copy("data/house_2024.csv", file.path(workspace, "data/house_2024.csv"))
  setwd(workspace)
  clock <- function() collector_time("2026-11-04T00:00:00Z")
  fetch <- function(state) {
    ids <- watch_districts[substr(watch_districts, 1, 2) == state]
    validate_results(data.frame(district_id = ids, d_votes_current = 2000, r_votes_current = 3000,
      election_date = "2026-11-03"))
  }
  first <- collect_results(fetch = fetch, clock = clock, ky_dir = folder)
  expect_equal(nrow(first$results), 10L)
  expect_equal(first$results$d_votes_current[first$results$district_id == "KY-06"], 3000)
  expect_true(file.exists("data/live/ky-import.csv"))
  unlink(file.path(folder, "candidates.xml"))
  expect_message(second <- collect_results(first, fetch = fetch, clock = clock, ky_dir = folder), "Missing Kentucky")
  expect_equal(second$providers$status[second$providers$provider == "KY"], "error")
  first_ky <- first$results[first$results$district_id == "KY-06", ]
  second_ky <- second$results[second$results$district_id == "KY-06", ]
  rownames(first_ky) <- rownames(second_ky) <- NULL
  expect_equal(second_ky, first_ky)
  expect_true(all(second$providers$status[second$providers$provider != "KY"] == "ok"))
  expect_error(collect_results(ky_file = "x.csv", ky_dir = folder), "Choose --ky-file or --ky-dir")
})
