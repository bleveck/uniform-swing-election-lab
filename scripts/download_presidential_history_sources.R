# Optional maintenance. The normal app uses bundled derived CSVs.
dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
download.file("https://dataverse.harvard.edu/api/access/datafile/2547168", "data/raw/jacobson_JOPrepfile1.tab", mode = "wb")
download.file("https://dataverse.harvard.edu/api/access/datafile/2547164", "data/raw/jacobson_JOPrepfile1_documentation.doc", mode = "wb")
download.file("https://dataverse.harvard.edu/api/datasets/:persistentId/?persistentId=doi:10.7910/DVN/29559", "data/raw/jacobson_dataverse_metadata.json", mode = "wb")
download.file("https://raw.githubusercontent.com/kuriwaki/ccesMRPprep/e4482502dbebc00ca4060c29c7e532272d4b03c6/data/cd_info_2018.rda", "data/raw/cces_cd_info_2018.rda", mode = "wb")
source("scripts/build_presidential_history.R")
