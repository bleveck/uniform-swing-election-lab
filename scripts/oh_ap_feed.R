# The same public AP service as KY, embedded by Signal Ohio for Ohio House races.
source("scripts/ap_house_feed.R")

oh_ap_panel <- "https://interactives.apelections.org/election-results/customers/layouts/organization-layouts/published/124546/35136.html"
# Verified against the public Ohio metadata index on election night, November 3.
oh_ap_races <- c("OH-07" = "20261103OH36027", "OH-09" = "20261103OH36031",
  "OH-10" = "20261103OH36033", "OH-15" = "20261103OH36043")
oh_ap_config <- lapply(names(oh_ap_races), function(id) list(
  state = "OH", seat = as.character(as.integer(sub("OH-", "", id))), district_id = id,
  race_id = unname(oh_ap_races[[id]]), opening = "2026-11-04 00:30:00",
  source = "AP via Signal Ohio public House panel", panel = oh_ap_panel,
  base = paste0("https://interactives.apelections.org/election-results/data-live/2026-11-03/results/races/OH/",
    oh_ap_races[[id]], "/")))
names(oh_ap_config) <- names(oh_ap_races)

fetch_oh_ap <- function(now = Sys.time(), download = download_public) {
  # Replace the four Ohio districts together. Any failed race retains the previous
  # Ohio snapshot, rather than publishing an incomplete or mixed-source state.
  validate_results(do.call(rbind, lapply(oh_ap_config, function(config) {
    fetch_ap_house(config, now, download)
  })))
}
