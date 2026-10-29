# Run from the project root after changing app code, runtime data, or packages.
# rsconnect is a publishing dependency; it is not loaded by the hosted app.
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Install the publishing helper first: install.packages('rsconnect')")
}
options(repos = c(CRAN = "https://cloud.r-project.org"))
source("scripts/deployment_files.R")
rsconnect::writeManifest(appDir = ".", appFiles = deployment_files(),
  appPrimaryDoc = "app.R", appMode = "shiny", quarto = FALSE)
cat("Wrote manifest.json for", length(deployment_files()), "runtime files.\n")
