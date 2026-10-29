# Maintenance only: readxl is not needed to run the app.
if (!requireNamespace("readxl", quietly = TRUE)) stop("Rebuilding this source requires the readxl package.")
source_file <- "data/raw/ca13_2024_cvf.xlsx"
x <- suppressMessages(readxl::read_excel(source_file, sheet = "CD-13", col_names = FALSE, col_types = "text"))
stopifnot(x[[1]][1] == "CD 13", grepl("John Duarte", x[[1]][3]), grepl("Adam Gray", x[[1]][4]))
row_numbers <- function(row) as.numeric(unlist(x[row, -1], use.names = FALSE))
dates <- as.Date(row_numbers(1), origin = "1899-12-30")
seconds <- round(86400 * row_numbers(2))
stopifnot(all(seconds >= 0 & seconds < 86400))
times <- sprintf("%02d:%02d", seconds %/% 3600, (seconds %% 3600) %/% 60)
out <- data.frame(snapshot = seq_along(dates), district_id = "CA-13", election_date = "2024-11-05",
  recorded_date = as.character(dates), recorded_time_source = times, source_time_zone = "Not specified",
  gray_votes = row_numbers(4), duarte_votes = row_numbers(3), reported_total = row_numbers(8),
  source = "California Voter Foundation, Close Count Transparency Project, CD-13",
  source_url = "https://docs.google.com/spreadsheets/d/1_sHIMjAD-bbgn7MsKLb9_U3bJQyB6FVq/edit",
  source_column = c(LETTERS, paste0("A", LETTERS))[seq_along(dates) + 1])
stopifnot(nrow(out) == 31L, out$recorded_date[1] == "2024-11-05", tail(out$recorded_date, 1) == "2024-12-05",
  all(out$gray_votes + out$duarte_votes == out$reported_total))
official <- read.csv("data/house_2024.csv")
official <- official[official$district_id == "CA-13", ]
stopifnot(tail(out$gray_votes, 1) == official$d_votes, tail(out$duarte_votes, 1) == official$r_votes,
  tail(out$gray_votes - out$duarte_votes, 1) == 187)
write.csv(out, "data/ca13_2024_returns.csv", row.names = FALSE)
cat(sprintf("Saved %d recorded CA-13 snapshots, %s to %s. Final Gray lead: 187 votes.\n", nrow(out), out$recorded_date[1], tail(out$recorded_date, 1)))
