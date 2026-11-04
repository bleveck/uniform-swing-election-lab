# Laptop-only reader for the public AP JSON used by WEKU's election widget.
# These are media-reported cumulative totals, not a Kentucky SOS download.
source("scripts/ap_house_feed.R")

ky_ap_config <- list(
  state = "KY", seat = "6", district_id = "KY-06",
  opening = "2026-11-03 23:00:00", source = "AP via WEKU public KY-06 panel",
  panel = "https://interactives.apelections.org/election-results/customers/layouts/organization-layouts/published/74947/40992.html",
  race_id = "20261103KY18015",
  base = "https://interactives.apelections.org/election-results/data-live/2026-11-03/results/races/KY/20261103KY18015/"
)

parse_ky_ap <- function(summary_path, metadata_path, now = Sys.time()) {
  parse_ap_house(summary_path, metadata_path, ky_ap_config, now)
}

fetch_ky_ap <- function(now = Sys.time(), download = download_public) {
  fetch_ap_house(ky_ap_config, now, download)
}
