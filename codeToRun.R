baseFolder <-
  file.path(dirname(rstudioapi::getActiveDocumentContext()$path))
studyOutputFolder <- file.path(baseFolder, "results")
# unlink(
#   x = file.path(baseFolder, "Specifications", "inst"),
#   recursive = TRUE,
#   force = TRUE
# )
# dir.create(
#   path = file.path(baseFolder, "Specifications", "inst"),
#   showWarnings = FALSE,
#   recursive = TRUE
# )
# 
# # from public atlas
# baseUrl <- Sys.getenv("ohdsiAtlasPhenotype")
# ROhdsiWebApi::authorizeWebApi(
#   baseUrl = baseUrl,
#   authMethod = "db",
#   webApiUsername = keyring::key_get("ohdsiAtlasPhenotypeUser"),
#   webApiPassword = keyring::key_get("ohdsiAtlasPhenotypePassword")
# )
# targetCohortIds <- c(66, 42, 39, 181, 204, 203, 202)
# cohortDefinitionSetOhdsi <-
#   ROhdsiWebApi::exportCohortDefinitionSet(
#     baseUrl = baseUrl,
#     cohortIds = c(targetCohortIds),
#     generateStats = TRUE
#   )
# 
# readr::write_excel_csv(
#   x = cohortDefinitionSetOhdsi %>%
#     dplyr::select(.data$cohortId,
#                   .data$atlasId,
#                   .data$cohortName) %>%
#     dplyr::arrange(.data$cohortId),
#   file = file.path(baseFolder, "Specifications", "inst", "Cohorts.csv"),
#   na = "",
#   append = FALSE,
#   quote = "all"
# )
# 
# ROhdsiWebApi::insertCohortDefinitionSetInPackage(
#   fileName = file.path(baseFolder, "Specifications", "inst", "Cohorts.csv"),
#   baseUrl = baseUrl,
#   jsonFolder = file.path(baseFolder, "Specifications", "inst", "Cohorts"),
#   sqlFolder = file.path(baseFolder, "Specifications", "inst", "sql", "sql_server"),
#   packageName = "",
#   generateStats = TRUE,
#   insertCohortCreationR = FALSE
# )
# 
# # JNJ atlas
# baseUrl <- Sys.getenv("BaseUrl")
# ROhdsiWebApi::authorizeWebApi(baseUrl = baseUrl,
#                               authMethod = "windows")
# targetCohortIds <- c(8976,
#                      8975,
#                      8563)
# cohortDefinitionSetJnj <-
#   ROhdsiWebApi::exportCohortDefinitionSet(
#     baseUrl = baseUrl,
#     cohortIds = c(targetCohortIds),
#     generateStats = TRUE
#   )
# 
# readr::write_excel_csv(
#   x = cohortDefinitionSetJnj %>%
#     dplyr::select(.data$cohortId,
#                   .data$atlasId,
#                   .data$cohortName) %>%
#     dplyr::arrange(.data$cohortId),
#   file = file.path(baseFolder, "Specifications", "inst", "Cohorts.csv"),
#   na = "",
#   append = FALSE,
#   quote = "all"
# )
# 
# ROhdsiWebApi::insertCohortDefinitionSetInPackage(
#   fileName = file.path(baseFolder, "Specifications", "inst", "Cohorts.csv"),
#   baseUrl = baseUrl,
#   jsonFolder = file.path(baseFolder, "Specifications", "inst", "Cohorts"),
#   sqlFolder = file.path(baseFolder, "Specifications", "inst", "sql", "sql_server"),
#   packageName = "",
#   generateStats = TRUE,
#   insertCohortCreationR = FALSE
# )
# 
# 
# readr::write_excel_csv(
#   x = dplyr::bind_rows(cohortDefinitionSetJnj,
#                        cohortDefinitionSetOhdsi) %>%
#     dplyr::select(.data$cohortId,
#                   .data$atlasId,
#                   .data$cohortName) %>%
#     dplyr::arrange(.data$cohortId),
#   file = file.path(baseFolder, "Specifications", "inst", "Cohorts.csv"),
#   na = "",
#   append = FALSE,
#   quote = "all"
# )

cohortTableNames <-
  CohortGenerator::getCohortTableNames(cohortTable = "ohdsi_aki")

databaseIds <- c(
  "cprd", "ims_australia_lpd", "ims_france", "ims_germany", "iqvia_amb_emr", "iqvia_pharmetrics_plus",
  "jmdc", "optum_ehr", "optum_extended_dod", "truven_ccae", "truven_mdcd", "truven_mdcr"
)

for (i in (1:length(databaseIds))) {
  cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
    settingsFileName = file.path(baseFolder, "Specifications", "inst", "Cohorts.csv"),
    jsonFolder = file.path(baseFolder, "Specifications", "inst", "Cohorts"),
    sqlFolder = file.path(baseFolder, "Specifications", "inst", "sql" , "sql_server"),
  ) %>%
    dplyr::tibble()
  
  databaseId <- databaseIds[[i]]
  
  cdmSource <- cdmSources %>%
    dplyr::filter(.data$database == databaseId) %>%
    dplyr::filter(.data$sequence == 1)
  
  connectionDetails <-
    DatabaseConnector::createConnectionDetails(
      dbms = cdmSource$sourceDialect,
      user = keyring::key_get("OHDSI_USER"),
      password = keyring::key_get("OHDSI_PASSWORD"),
      server = cdmSource$server,
      port = cdmSource$port
    )
  
  CohortGenerator::createCohortTables(
    connectionDetails = connectionDetails,
    cohortDatabaseSchema = cdmSource$cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    incremental = TRUE
  )
  
  CohortGenerator::generateCohortSet(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmSource$cdmDatabaseSchema,
    cohortDatabaseSchema = cdmSource$cohortDatabaseSchema,
    incremental = TRUE,
    incrementalFolder = file.path(
      studyOutputFolder,
      "Results",
      "CohortGeneration",
      databaseId,
      "Incremental"
    ),
    cohortTableNames = cohortTableNames,
    cohortDefinitionSet = cohortDefinitionSet
  )
  
  cohortDiagnosticsExportFolder <- file.path(studyOutputFolder,
                                             "Results",
                                             "CohortDiagnostics",
                                             databaseId)
  
  dir.create(path = cohortDiagnosticsExportFolder,
             showWarnings = FALSE,
             recursive = TRUE)
  
  CohortDiagnostics::executeDiagnostics(
    cohortDefinitionSet = cohortDefinitionSet,
    exportFolder = cohortDiagnosticsExportFolder,
    databaseId = cdmSource$database,
    cohortDatabaseSchema = cdmSource$cohortDatabaseSchema,
    databaseName = cdmSource$database,
    databaseDescription = cdmSource$database,
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmSource$cdmDatabaseSchema,
    cohortTableNames = cohortTableNames,
    minCellCount = 5,
    runTimeSeries = FALSE,
    runVisitContext = TRUE,
    runIncidenceRate = TRUE,
    runCohortRelationship = TRUE,
    runTemporalCohortCharacterization = TRUE,
    incremental = TRUE
  )
}

# CohortDiagnostics::createMergedResultsFile(dataFolder = file.path(studyOutputFolder, "Results", "CohortDiagnostics"),
#                                            sqliteDbPath = file.path(studyOutputFolder, "Results", "CohortDiagnostics", "MergedCohortDiagnosticsData.sqlite"),
#                                            overwrite = TRUE
# )