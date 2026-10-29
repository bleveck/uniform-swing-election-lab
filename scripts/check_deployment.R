# Validate the exact files and package versions that Connect Cloud will receive.
check_deployment <- function() {
  source("scripts/deployment_files.R", local = TRUE)
  manifest <- jsonlite::read_json("manifest.json")
  stopifnot(identical(manifest$metadata$appmode, "shiny"))
  files <- deployment_files()
  if (!setequal(files, names(manifest$files))) {
    stop("Deployment file list changed. Run Rscript scripts/write_manifest.R")
  }
  recorded <- vapply(manifest$files[files], function(x) x$checksum, character(1))
  actual <- tools::md5sum(files)
  changed <- files[recorded != actual]
  if (length(changed)) {
    stop("Stale manifest checksums: ", paste(changed, collapse = ", "),
      ". Run Rscript scripts/write_manifest.R")
  }
  for (name in names(manifest$packages)) {
    package <- manifest$packages[[name]]
    if (!identical(package$Source, "CRAN") || is.null(package$Repository)) {
      stop("Package has no public repository: ", name)
    }
    if (!requireNamespace(name, quietly = TRUE) ||
        utils::packageVersion(name) != package_version(package$description$Version)) {
      stop("Installed package differs from deployment manifest: ", name)
    }
  }

  # Loading from a temporary bundle catches accidental dependencies on raw
  # archives, local output files, or other files omitted from deployment.
  bundle <- tempfile("uniform-swing-bundle-")
  dir.create(bundle)
  old_dir <- getwd()
  on.exit({setwd(old_dir); unlink(bundle, recursive = TRUE)}, add = TRUE)
  for (file in files) {
    target <- file.path(bundle, file)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(file, target)) stop("Could not stage ", file)
  }
  setwd(bundle)
  options(sass.cache = FALSE)
  app <- new.env(parent = globalenv())
  sys.source("app.R", envir = app)
  stopifnot(is.function(app$server), nrow(app$house_baseline) == 435L,
    nrow(app$pres_baseline) == 435L, nrow(app$ca13_returns) == 31L)
  cat("Deployment bundle loads with", length(files), "files and",
    length(manifest$packages), "pinned runtime packages.\n")
}
check_deployment()
