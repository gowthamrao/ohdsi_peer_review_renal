# Using the official uploading functions to get data from zip files into the postgres database
# remotes::install_github("OHDSI/CohortDiagnostics")
if (exists("listOfZipFilesToUpload")) {
  listOfZipFilesToUpload2 <- listOfZipFilesToUpload
  if (!exists("listOfZipFilesToUpload2")) {
    listOfZipFilesToUpload2 <- c()
  }
} else {
  listOfZipFilesToUpload <- c()
  listOfZipFilesToUpload2 <- c()
}

library(CohortDiagnostics)

# OHDSI's server:
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste0(
    Sys.getenv("phenotypeLibraryServer"),
    "/",
    Sys.getenv("phenotypeLibrarydb")
  ),
  port = Sys.getenv("phenotypeLibraryDbPort", unset = 5432),
  user = Sys.getenv("phenotypeLibrarydbUser"),
  password = Sys.getenv("phenotypeLibrarydbPw")
)
resultsSchema <- 'peer_aki'

# commenting this function as it maybe accidentally run - loosing data.
# DatabaseConnector::renderTranslateExecuteSql(
#   connection = DatabaseConnector::connect(connectionDetails = connectionDetails),
#   sql = "CREATE SCHEMA IF NOT EXISTS @results_database_schema;",
#   results_database_schema = resultsSchema
# )
# createResultsDataModel(connectionDetails = connectionDetails, schema = resultsSchema)
sqlGrant <-
  paste0("grant select on all tables in schema ",
         resultsSchema,
         " to phenotypelibrary;")
DatabaseConnector::renderTranslateExecuteSql(
  connection = DatabaseConnector::connect(connectionDetails = connectionDetails),
  sql = sqlGrant
)

sqlGrantTable <- "GRANT ALL ON  @results_database_schema.annotation TO  phenotypelibrary;
                  GRANT ALL ON  @results_database_schema.annotation_link TO  phenotypelibrary;
                  GRANT ALL ON  @results_database_schema.annotation_attributes TO  phenotypelibrary;"

DatabaseConnector::renderTranslateExecuteSql(
  connection = DatabaseConnector::connect(connectionDetails = connectionDetails),
  sql = sqlGrantTable,
  results_database_schema = resultsSchema
)

Sys.setenv("POSTGRES_PATH" = Sys.getenv('POSTGRES_PATH'))

baseFolder <-
  file.path(dirname(rstudioapi::getActiveDocumentContext()$path))
studyOutputFolder <- file.path(baseFolder, "results")

listOfZipFilesToUpload <-
  list.files(
    path = studyOutputFolder,
    pattern = ".zip",
    full.names = TRUE,
    recursive = TRUE
  )

listOfZipFilesToUpload <-
  setdiff(listOfZipFilesToUpload, listOfZipFilesToUpload2)

# listOfZipFilesToUpload <-
#   listOfZipFilesToUpload[stringr::str_detect(string = listOfZipFilesToUpload,
#                                              pattern = "optum",
#                                              negate = TRUE)]

for (i in (1:length(listOfZipFilesToUpload))) {
  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = resultsSchema,
    zipFileName = listOfZipFilesToUpload[[i]]
  )
}

listOfZipFilesToUpload2 <-
  c(listOfZipFilesToUpload, listOfZipFilesToUpload2) %>% unique() %>% sort()
