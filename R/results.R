# Shared result validation for ordinary R and browser R.
empty_results <- function() data.frame(district_id = character(), d_votes_current = numeric(),
  r_votes_current = numeric(), election_date = character(), source = character(),
  fetched_at = character(), source_updated_at = character(), is_test = logical())

utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

validate_results <- function(x, expected_date = "2026-11-03") {
  required <- c("district_id", "d_votes_current", "r_votes_current", "election_date")
  missing <- setdiff(required, names(x))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
  x$district_id <- toupper(trimws(x$district_id))
  if (anyDuplicated(x$district_id)) stop("Duplicate district rows: supply one cumulative total per district.")
  known <- read.csv("data/house_2024.csv")$district_id
  if (any(!x$district_id %in% known)) stop("Unknown district ID. Use IDs such as KY-06 and VA-01.")
  for (col in c("d_votes_current", "r_votes_current")) {
    x[[col]] <- suppressWarnings(as.numeric(x[[col]]))
    if (any(!is.finite(x[[col]]) | x[[col]] < 0 | x[[col]] != floor(x[[col]]))) stop("Vote counts must be finite, nonnegative whole numbers.")
  }
  if (anyNA(x$election_date) || any(x$election_date != expected_date)) stop("Wrong election date; expected ", expected_date, ".")
  if (!"source" %in% names(x)) x$source <- "Manual CSV"
  if (!"fetched_at" %in% names(x)) x$fetched_at <- utc_now()
  if (!"source_updated_at" %in% names(x)) x$source_updated_at <- NA_character_
  if (!"is_test" %in% names(x)) x$is_test <- FALSE
  x$is_test <- as.logical(x$is_test)
  if (anyNA(x$is_test)) stop("is_test must be TRUE or FALSE.")
  x[, names(empty_results()), drop = FALSE]
}

`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
