# Local files only. Kentucky's 2026 Data Website Guide v6 describes this schema.
# No HTTP requests are made by this importer.
ky_xml_nodes <- function(doc, name) xml2::xml_find_all(doc,
  paste0("//*[local-name()='", name, "']"), ns = character())

ky_xml_table <- function(doc, record, fields, predicate = NULL) {
  # The real SummaryReport has a CandidateData collection containing records
  # also named CandidateData. Select leaf records rather than that collection.
  xpath <- paste0("//*[local-name()='", record, "' and not(*[local-name()='", record, "'])]",
    if (!is.null(predicate)) paste0("[", predicate, "]") else "")
  nodes <- xml2::xml_find_all(doc, xpath, ns = character())
  if (!length(nodes)) stop("No ", record, " records in the selected XML file.")
  columns <- lapply(fields, function(field) {
    children <- xml2::xml_find_all(nodes, paste0("./*[local-name()='", field, "']"),
      ns = character(), flatten = FALSE)
    if (any(lengths(children) != 1L)) stop(record, " must have exactly one ", field, " field. Use the 2026 v6 downloads.")
    vapply(children, function(child) trimws(xml2::xml_text(child)), character(1))
  })
  names(columns) <- fields
  as.data.frame(columns, stringsAsFactors = FALSE)
}

ky_download_files <- function(folder) {
  if (!dir.exists(folder)) stop("Kentucky download folder does not exist: ", folder)
  paths <- list.files(folder, pattern = "\\.xml$", ignore.case = TRUE, full.names = TRUE)
  if (!length(paths)) stop("No XML files in the Kentucky folder. Download the six files listed in docs/kentucky-import.md.")
  roles <- c(results = "CandidateDataList", elections = "Election", parties = "PoliticalParty",
    units = "GeopoliticalUnit", contests = "Contest", candidates = "Candidate")
  found <- setNames(vector("list", length(roles)), names(roles))
  for (path in paths) {
    doc <- tryCatch(xml2::read_xml(path, options = c("NONET", "NOBLANKS")),
      error = function(e) stop("Cannot read ", basename(path), " as XML. Finish the download/copy before importing."))
    if (tolower(xml2::xml_name(xml2::xml_root(doc))) == "html") {
      stop(basename(path), " is a web/error page, not a Kentucky XML download.")
    }
    for (role in names(roles)) {
      matched <- length(ky_xml_nodes(doc, roles[[role]])) > 0L
      if (role == "results") matched <- matched || length(ky_xml_nodes(doc, "CandidateData")) > 0L
      if (matched) found[[role]] <- c(found[[role]], list(list(path = path, doc = doc)))
    }
  }
  missing <- names(found)[!lengths(found)]
  if (length(missing)) stop("Missing Kentucky XML datasets: ", paste(missing, collapse = ", "), ". See docs/kentucky-import.md.")
  lapply(found, function(candidates) {
    times <- vapply(candidates, function(x) as.numeric(file.info(x$path)$mtime), numeric(1))
    if (any(!is.finite(times))) stop("Cannot determine a download's modification time.")
    latest <- which(times == max(times))
    if (length(latest) > 1L && length(unique(tools::md5sum(vapply(candidates[latest], `[[`, "", "path")))) > 1L) {
      stop("Different XML downloads share the newest modification time. Move older copies out of the import folder.")
    }
    candidates[[latest[1]]]
  })
}

ky_unique_ids <- function(x, field) {
  if (anyNA(x[[field]]) || any(!nzchar(x[[field]])) || anyDuplicated(x[[field]])) stop("Missing or duplicate Kentucky ", field, ".")
  invisible(x)
}

ky_bool <- function(x, field) {
  value <- tolower(trimws(x))
  if (anyNA(value) || any(!value %in% c("true", "false", "1", "0"))) stop("Invalid Kentucky ", field, " flag.")
  value %in% c("true", "1")
}

ky_test_flag <- function(doc) {
  fields <- c("istest", "ismock", "testdata")
  test <- paste0("translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='", fields, "'", collapse = " or ")
  values <- c(xml2::xml_text(xml2::xml_find_all(doc, paste0("//*[", test, "]"), ns = character())),
    xml2::xml_text(xml2::xml_find_all(doc, paste0("//@*[", test, "]"), ns = character())))
  if (!length(values)) return(FALSE)
  any(ky_bool(values, "test-data"))
}

ky_source_clock <- function(doc) {
  root <- xml2::xml_root(doc)
  fields <- c("generateddate", "generatedat", "createdat", "lastupdated", "updatedat", "timestamp")
  attrs <- xml2::xml_attrs(root)
  values <- unname(attrs[tolower(names(attrs)) %in% fields])
  children <- xml2::xml_children(root)
  values <- c(values, xml2::xml_text(children[tolower(xml2::xml_name(children)) %in% fields]))
  values <- unique(trimws(values[nzchar(values)]))
  if (length(values) > 1L) stop("Conflicting Kentucky publication timestamps.")
  if (length(values)) values else NA_character_
}

read_ky_downloads <- function(folder, now = Sys.time(), force_test = FALSE) {
  files <- ky_download_files(folder)
  election <- ky_xml_table(files$elections$doc, "Election", c("ElectionDate", "ElectionName", "ElectionType"))
  date_text <- sub("T.*$", "", election$ElectionDate)
  dates <- as.Date(date_text, format = "%Y-%m-%d")
  mdy <- is.na(dates)
  dates[mdy] <- as.Date(date_text[mdy], format = "%m/%d/%Y")
  if (nrow(election) != 1L || is.na(dates[1]) || dates[1] != as.Date("2026-11-03") ||
      !grepl("general", election$ElectionName[1], ignore.case = TRUE) ||
      grepl("primary", election$ElectionType[1], ignore.case = TRUE)) {
    stop("Expected metadata for the November 3, 2026 general election. Download all files from that election's page.")
  }
  parties <- ky_xml_table(files$parties$doc, "PoliticalParty", c("PartyId", "Abbreviation", "PartyName"))
  contests <- ky_xml_table(files$contests$doc, "Contest", c("ContestId", "ContestName", "ContestScopeUnitId"))
  candidates <- ky_xml_table(files$candidates$doc, "Candidate",
    c("CandidateId", "ContestId", "BallotName", "PoliticalPartyId", "IsWriteIn", "IsWithdrawn"))
  units <- ky_xml_table(files$units$doc, "GeopoliticalUnit", c("UnitId", "ParentId", "UnitName", "UnitType"))
  # The v6 guide lists numeric enum values; real XML serializes their names.
  kinds <- c(country = "10", state = "11", county = "12", city = "13", precinct = "17",
    school = "111", schoolboard = "111", schoolboards = "111")
  type <- tolower(gsub("[^a-z0-9]", "", units$UnitType, ignore.case = TRUE))
  named <- type %in% names(kinds)
  units$UnitType[named] <- unname(kinds[type[named]])
  for (pair in list(list(parties, "PartyId"), list(contests, "ContestId"),
      list(candidates, "CandidateId"), list(units, "UnitId"))) ky_unique_ids(pair[[1]], pair[[2]])
  label <- toupper(gsub("[^A-Za-z0-9]+", " ", contests$ContestName))
  house <- grepl("\\b(UNITED STATES|U S|US|CONGRESS|CONGRESSIONAL)\\b", label) &
    grepl("\\b(REPRESENTATIVE|HOUSE|CONGRESS|CONGRESSIONAL)\\b", label) &
    grepl("\\b(0?6|6TH|SIXTH)\\b", label)
  if (sum(house) != 1L) stop("Could not identify exactly one U.S. House district 6 contest in the XML metadata.")
  contest <- contests[house, , drop = FALSE]
  cands <- candidates[candidates$ContestId == contest$ContestId, , drop = FALSE]
  write_in <- ky_bool(cands$IsWriteIn, "IsWriteIn")
  abbreviation <- toupper(parties$Abbreviation[match(cands$PoliticalPartyId, parties$PartyId)])
  party_name <- toupper(parties$PartyName[match(cands$PoliticalPartyId, parties$PartyId)])
  cands$major <- ifelse(abbreviation %in% c("D", "DEM", "DEMOCRAT", "DEMOCRATIC") |
      party_name %in% c("DEMOCRAT", "DEMOCRATIC", "DEMOCRATIC PARTY"), "D",
    ifelse(abbreviation %in% c("R", "REP", "REPUBLICAN") | party_name %in% c("REPUBLICAN", "REPUBLICAN PARTY"), "R", NA_character_))
  cands <- cands[!write_in & !is.na(cands$major), , drop = FALSE]
  if (nrow(cands) != 2L || !setequal(cands$major, c("D", "R"))) {
    stop("KY-06 must have exactly one non-write-in Democratic and one Republican candidate.")
  }
  if (any(ky_bool(cands$IsWithdrawn, "IsWithdrawn"))) stop("A selected KY-06 major-party candidate is marked withdrawn.")
  if (!grepl("^[0-9]+$", contest$ContestId)) stop("Invalid Kentucky contest ID.")
  results <- ky_xml_table(files$results$doc, "CandidateData",
    c("ContestId", "CandidateId", "ReportingUnitId", "TotalVotes"),
    paste0("*[local-name()='ContestId' and text()='", contest$ContestId, "']"))
  if (!nrow(results)) stop("The current-results XML contains no KY-06 records yet.")
  if (any(!results$CandidateId %in% candidates$CandidateId[candidates$ContestId == contest$ContestId])) {
    stop("KY-06 result candidate IDs do not match the candidate metadata.")
  }
  results <- results[results$CandidateId %in% cands$CandidateId, , drop = FALSE]
  if (!nrow(results)) stop("The current-results XML has no major-party KY-06 totals yet.")
  results$votes <- suppressWarnings(as.numeric(results$TotalVotes))
  if (any(!grepl("^[0-9]+$", results$TotalVotes)) || any(!is.finite(results$votes)) ||
      any(results$votes > 2^53 - 1)) stop("Invalid Kentucky vote counts; expected nonnegative whole numbers.")
  if (anyDuplicated(paste(results$CandidateId, results$ReportingUnitId, sep = "|"))) {
    stop("Duplicate Kentucky candidate/reporting-unit rows; totals would be ambiguous.")
  }
  if (any(!results$ReportingUnitId %in% units$UnitId)) stop("Results reference unknown Kentucky reporting units.")
  state <- units[units$UnitType == "11" & toupper(trimws(units$UnitName)) == "KENTUCKY", , drop = FALSE]
  if (nrow(state) != 1L) stop("Could not identify the Kentucky state reporting unit.")
  ancestors <- function(id) {
    path <- character()
    while (id != state$UnitId) {
      if (id %in% path) stop("Cycle in Kentucky reporting-unit hierarchy.")
      path <- c(path, id)
      i <- match(id, units$UnitId)
      if (is.na(i) || !units$UnitType[i] %in% c("12", "17")) {
        stop("Unsupported KY-06 reporting-unit hierarchy; expected state/county/precinct records.")
      }
      id <- units$ParentId[i]
      if (!nzchar(id) || !id %in% units$UnitId) stop("Incomplete Kentucky reporting-unit hierarchy.")
    }
    c(path[-1], state$UnitId)
  }
  present <- unique(results$ReportingUnitId)
  # Keep each highest available summary and omit its descendants. This also
  # supports county summaries mixed with precincts in other, uncovered counties.
  above <- setNames(lapply(present, function(id) if (id == state$UnitId) character() else ancestors(id)), present)
  selected <- present[!vapply(above, function(ids) any(ids %in% present), logical(1))]
  chosen <- results[results$ReportingUnitId %in% selected, , drop = FALSE]
  for (id in selected) {
    if (!setequal(chosen$CandidateId[chosen$ReportingUnitId == id], cands$CandidateId)) {
      stop("A selected KY-06 reporting unit lacks one major-party candidate's total.")
    }
  }
  votes <- setNames(vapply(c("D", "R"), function(party)
    sum(chosen$votes[chosen$CandidateId == cands$CandidateId[cands$major == party]]), numeric(1)), c("D", "R"))
  if (any(votes > 2^53 - 1)) stop("Kentucky aggregate exceeds exact numeric precision.")
  fetched <- file.info(files$results$path)$mtime
  if (is.na(fetched) || fetched > now + 300) stop("Invalid/future download modification time; check the laptop clock.")
  opening <- as.POSIXct("2026-11-03 23:00:00", tz = "UTC")
  source_clock <- ky_source_clock(files$results$doc)
  published <- if (!is.na(source_clock) && grepl("^\\d{4}-\\d{2}-\\d{2}T.*Z$", source_clock)) {
    as.POSIXct(source_clock, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  } else as.POSIXct(NA)
  is_test <- isTRUE(force_test) || fetched < opening || now < opening ||
    (!is.na(published) && published < opening) || any(vapply(files, function(x) ky_test_flag(x$doc), logical(1)))
  row <- validate_results(data.frame(district_id = "KY-06", d_votes_current = votes[["D"]],
    r_votes_current = votes[["R"]], election_date = "2026-11-03", source = "KY SOS manually downloaded XML",
    fetched_at = format(fetched, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), source_updated_at = source_clock,
    is_test = is_test, stringsAsFactors = FALSE))
  list(results = row, contest = contest$ContestName, candidates = cands,
    selected_units = units[match(selected, units$UnitId), ],
    files = vapply(files, `[[`, "", "path"))
}

import_ky_downloads <- function(folder, output = "data/live/ky-import.csv", now = Sys.time(), force_test = FALSE) {
  parsed <- read_ky_downloads(folder, now, force_test)
  row <- parsed$results
  if (file.exists(output)) {
    old <- validate_results(read.csv(output, stringsAsFactors = FALSE))
    if (nrow(old) != 1L || old$district_id != "KY-06") stop("Existing Kentucky import output is not a KY-06 snapshot.")
    old_time <- as.POSIXct(old$fetched_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    new_time <- as.POSIXct(row$fetched_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    if (is.na(old_time) || old_time > new_time) stop("Refusing to replace the Kentucky CSV with an older/undated download.")
    if (isTRUE(all.equal(old, row, check.attributes = FALSE))) return(parsed)
  }
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile("ky-import-", tmpdir = dirname(output), fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)
  write.csv(row, temporary, row.names = FALSE, na = "")
  # The collector must not mistake conversion time for a new manual download.
  if (!Sys.setFileTime(temporary, file.info(parsed$files[["results"]])$mtime)) stop("Could not preserve the download time.")
  if (!file.rename(temporary, output)) stop("Could not replace Kentucky CSV: ", output)
  parsed
}
