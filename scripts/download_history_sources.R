# Optional source refresh for the empirical prior. Requires the app dependencies.
options(timeout = 120)
medsl_commit <- "fe67c056502fc09ddb1ace2ff8f87c53233a744e"
boundaries_commit <- "3c663a8098b58156601e0893f0e67b502f7f8354"
download.file("https://osf.io/download/8dzt5/", "data/raw/wolf_house_1896_2014.csv", mode = "wb")
download.file("https://osf.io/download/3na27/", "data/raw/wolf_codebook.md", mode = "wb")
download.file(paste0("https://raw.githubusercontent.com/MEDSL/constituency-returns/", medsl_commit, "/1976-2018-house.csv"), "data/raw/medsl_house_1976_2018.csv", mode = "wb")
tree_file <- tempfile(fileext = ".json")
download.file(paste0("https://api.github.com/repos/JeffreyBLewis/congressional-district-boundaries/git/trees/", boundaries_commit, "?recursive=1"), tree_file, mode = "wb")
tree <- jsonlite::fromJSON(tree_file)$tree
unlink(tree_file)
paths <- tree[grepl("^GeoJson/.+_[0-9]+_to_[0-9]+\\.geojson$", tree$path), ]
matches <- regmatches(paths$path, regexec("^GeoJson/(.+)_([0-9]+)_to_([0-9]+)\\.geojson$", paths$path))
vintages <- data.frame(state_name = vapply(matches, `[`, character(1), 2),
  start_congress = as.integer(vapply(matches, `[`, character(1), 3)),
  end_congress = as.integer(vapply(matches, `[`, character(1), 4)), source_path = paths$path, blob_sha = paths$sha)
stopifnot(nrow(vintages) > 800)
write.csv(vintages, "data/raw/boundary_vintages.csv", row.names = FALSE)
source("scripts/build_history.R")
