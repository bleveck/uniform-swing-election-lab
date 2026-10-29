packages <- c("shiny", "bslib", "ggplot2", "httr2", "jsonlite", "xml2", "testthat")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
cat("Dependencies ready. Run shiny::runApp('.') from this directory.\n")
