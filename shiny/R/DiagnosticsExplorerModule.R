diagnosticsExplorerModule <- function(id = "DiagnosticsExplorer",
                                      envir = .GlobalEnv,
                                      dataSource = envir$dataSource,
                                      databaseTable = envir$database,
                                      cohortTable = envir$cohort,
                                      enableAnnotation = envir$enableAnnotation,
                                      enableAuthorization = envir$enableAuthorization,
                                      enabledTabs = envir$enabledTabs,
                                      conceptSets = envir$conceptSets,
                                      userCredentials = envir$userCredentials,
                                      activeUser = envir$activeUser) {
  ns <- shiny::NS(id)
  shiny::moduleServer(id, function(input, output, session) {

    activeLoggedInUser <- reactiveVal(activeUser)
    if (enableAnnotation & nrow(userCredentials) > 0) {
      shiny::observeEvent(
        eventExpr = input$annotationUserPopUp,
        handlerExpr = {
          shiny::showModal(
            shiny::modalDialog(
              title = "Annotate",
              easyClose = TRUE,
              size = "s",
              footer = tagList(
                shiny::actionButton(inputId = ns("login"), label = "Login"),
                shiny::modalButton("Cancel")
              ),
              tags$div(
                shiny::textInput(
                  inputId = ns("userName"),
                  label = "Username",
                  width = NULL,
                  value = if (enableAuthorization) {
                    ""
                  } else {
                    "annonymous"
                  }
                ),
                if (enableAuthorization) {
                  shiny::passwordInput(
                    inputId = ns("password"),
                    label = "Password",
                    width = NULL
                  )
                },
              )
            )
          )
        }
      )

      shiny::observeEvent(
        eventExpr = input$login,
        handlerExpr = {
          tryCatch(
            expr = {
              if (enableAuthorization) {
                if (input$userName == "" || input$password == "") {
                  activeLoggedInUser(NULL)
                  shiny::showModal(
                    shiny::modalDialog(
                      title = "Error",
                      easyClose = TRUE,
                      size = "s",
                      fade = TRUE,
                      "Please enter both the fields"
                    )
                  )
                }
                userCredentialsFiltered <- userCredentials %>%
                  dplyr::filter(.data$userId == input$userName)
                if (nrow(userCredentialsFiltered) > 0) {
                  passwordHash <-
                    digest::digest(input$password, algo = "sha512")
                  if (passwordHash %in% userCredentialsFiltered$hashCode) {
                    activeLoggedInUser(input$userName)
                    shiny::removeModal()
                  } else {
                    activeLoggedInUser(NULL)
                    shiny::showModal(
                      shiny::modalDialog(
                        title = "Error",
                        easyClose = TRUE,
                        size = "s",
                        fade = TRUE,
                        "Invalid User"
                      )
                    )
                  }
                } else {
                  activeLoggedInUser(NULL)
                  shiny::showModal(
                    shiny::modalDialog(
                      title = "Error",
                      easyClose = TRUE,
                      size = "s",
                      fade = TRUE,
                      "Invalid User"
                    )
                  )
                }
              } else {
                if (input$userName == "") {
                  activeLoggedInUser(NULL)
                  shiny::showModal(
                    shiny::modalDialog(
                      title = "Error",
                      easyClose = TRUE,
                      size = "s",
                      fade = TRUE,
                      "Please enter the user name."
                    )
                  )
                } else {
                  activeLoggedInUser(input$userName)
                  shiny::removeModal()
                }
              }
            },
            error = function() {
              activeLoggedInUser(NULL)
            }
          )
        }
      )
    }

    output$userNameLabel <- shiny::renderText({
      if (is.null(activeLoggedInUser())) {
        return("")
      }
      paste(as.character(icon("user-circle")),
            stringr::str_to_title(activeLoggedInUser()))

    })

    # Display login based on value of active logged in user
    postAnnotaionEnabled <- shiny::reactive(!is.null(activeLoggedInUser()))
    output$postAnnoataionEnabled <- shiny::reactive({
      postAnnotaionEnabled()
    })

    output$signInButton <- shiny::renderUI({
      if (enableAuthorization & !postAnnotaionEnabled()) {
        return(
          shiny::actionButton(
            inputId = ns("annotationUserPopUp"),
            label = "Sign in"
          )
        )
      } else {
        return(shiny::span())
      }
    })

    outputOptions(output, "postAnnoataionEnabled", suspendWhenHidden = FALSE)

    if (enableAnnotation) {
      #--- Annotation modules
      annotationModules <- c("cohortCountsAnnotation",
                             "timeDistributionAnnotation",
                             "conceptsInDataSourceAnnotation",
                             "orphanConceptsAnnotation",
                             "inclusionRuleStatsAnnotation",
                             "indexEventBreakdownAnnotation",
                             "visitContextAnnotation",
                             "cohortOverlapAnnotation",
                             "cohortCharacterizationAnnotation",
                             "temporalCharacterizationAnnotation",
                             "compareCohortCharacterizationAnnotation",
                             "compareTemporalCharacterizationAnnotation")


      for (module in annotationModules) {
        annotationModule(id = module,
                         dataSource = dataSource,
                         activeLoggedInUser = activeLoggedInUser,
                         selectedDatabaseIds = selectedDatabaseIds,
                         selectedCohortIds = inputCohortIds,
                         cohortTable = cohortTable,
                         databaseTable = databaseTable,
                         postAnnotaionEnabled = postAnnotaionEnabled)
      }
    }

    # Reacive: targetCohortId
    targetCohortId <- shiny::reactive({
      return(cohortTable$cohortId[cohortTable$compoundName == input$targetCohort])
    })

    # ReactiveVal: cohortIds
    cohortIds <- reactiveVal(NULL)
    shiny::observeEvent(eventExpr = {
      list(
        input$cohorts,
        input$tabs
      )
    }, handlerExpr = {
      if (isFALSE(input$cohorts_open) || !is.null(input$tabs)) {
        selectedCohortIds <-
          cohortTable$cohortId[cohortTable$compoundName %in% input$cohorts]
        cohortIds(selectedCohortIds)
      }
    })

    # Reacive: comparatorCohortId
    comparatorCohortId <- shiny::reactive({
      return(cohortTable$cohortId[cohortTable$compoundName == input$comparatorCohort])
    })

    selectedConceptSets <- reactiveVal(NULL)
    shiny::observeEvent(eventExpr = {
      list(
        input$conceptSetsSelected_open,
        input$tabs
      )
    }, handlerExpr = {
      if (isFALSE(input$conceptSetsSelected_open) || !is.null(input$tabs)) {
        selectedConceptSets(input$conceptSetsSelected)
      }
    })

    # conceptSetIds ----
    conceptSetIds <- shiny::reactive(x = {
      conceptSetsFiltered <- conceptSets %>%
        dplyr::filter(.data$conceptSetName %in% selectedConceptSets()) %>%
        dplyr::filter(.data$cohortId %in% targetCohortId()) %>%
        dplyr::select(.data$conceptSetId) %>%
        dplyr::pull() %>%
        unique()
      return(conceptSetsFiltered)
    })

    timeIds <- reactiveVal(NULL)
    shiny::observeEvent(eventExpr = {
      list(
        input$timeIdChoices_open,
        input$tabs
      )
    }, handlerExpr = {
      if ("temporalCharacterizationTimeIdChoices" %in% enabledTabs &
        (isFALSE(input$timeIdChoices_open) ||
          !is.null(input$tabs))) {
        if (!is.null(envir$temporalChoices)) {
          selectedTimeIds <- envir$temporalCharacterizationTimeIdChoices %>%
            dplyr::filter(.data$temporalChoices %in% input$timeIdChoices) %>%
            dplyr::pull(.data$timeId)
          timeIds(selectedTimeIds)
        }
      }
    })

    databaseChoices <- list()
    dbMapping <- databaseTable
    for (i in 1:nrow(dbMapping)) {
      row <- dbMapping[i,]
      databaseChoices[row$databaseName] <- row$databaseId
    }

    ## ReactiveValue: selectedDatabaseIds ----
    selectedDatabaseIds <- reactiveVal(databaseChoices[[1]])
    shiny::observeEvent(eventExpr = {
      list(input$databases_open)
    }, handlerExpr = {
      if (isFALSE(input$databases_open)) {
        selectedDatabaseIds(input$databases)
      }
    })

    shiny::observeEvent(eventExpr = {
      list(input$database_open)
    }, handlerExpr = {
      if (isFALSE(input$database_open)) {
        selectedDatabaseIds(input$database)
      }
    })

    shiny::observeEvent(eventExpr = {
      list(input$tabs)
    }, handlerExpr = {
      if (!is.null(input$tabs)) {
        if (input$tabs %in% c(
          "compareCohortCharacterization",
          "compareTemporalCharacterization",
          "temporalCharacterization",
          "databaseInformation"
        )) {
          selectedDatabaseIds(input$database)
        } else {
          selectedDatabaseIds(input$databases)
        }
      }
    })

    ## Note - the following two database pickers could be improved by setting the multiple parameter to depend on the
    ## input$tabs variable for the selected tab. However, careful consideration needs to be taken as this can lead
    ## To even more confusing ux
    output$databasePicker <- shiny::renderUI({
      shinyWidgets::pickerInput(
        inputId = ns("database"),
        label = "Database",
        choices = databaseChoices,
        selected = databaseChoices[[1]],
        multiple = FALSE,
        choicesOpt = list(style = rep_len("color: black;", 999)),
        options = shinyWidgets::pickerOptions(
          actionsBox = TRUE,
          liveSearch = TRUE,
          size = 10,
          liveSearchStyle = "contains",
          liveSearchPlaceholder = "Type here to search",
          virtualScroll = 50
        )
      )
    })

    ## This is for multiple databases
    output$databasesPicker <- shiny::renderUI({
      shinyWidgets::pickerInput(
        inputId = ns("databases"),
        label = "Database",
        choices = databaseChoices,
        selected = databaseChoices[[1]],
        multiple = TRUE,
        choicesOpt = list(style = rep_len("color: black;", 999)),
        options = shinyWidgets::pickerOptions(
          actionsBox = TRUE,
          liveSearch = TRUE,
          size = 10,
          liveSearchStyle = "contains",
          liveSearchPlaceholder = "Type here to search",
          virtualScroll = 50
        )
      )
    })

    # Temporal choices (e.g. -30d - 0d ) are dynamic to execution input
    output$timeIdChoices <- shiny::renderUI({
      shinyWidgets::pickerInput(
        inputId = ns("timeIdChoices"),
        label = "Temporal Choice",
        choices = envir$
          temporalCharacterizationTimeIdChoices$
          temporalChoices,
        multiple = TRUE,
        choicesOpt = list(style = rep_len("color: black;", 999)),
        selected = envir$temporalCharacterizationTimeIdChoices %>%
          dplyr::filter(.data$primaryTimeId == 1) %>%
          dplyr::filter(.data$isTemporal == 1) %>%
          dplyr::arrange(.data$sequence) %>%
          dplyr::pull("temporalChoices"),
        options = shinyWidgets::pickerOptions(
          actionsBox = TRUE,
          liveSearch = TRUE,
          size = 10,
          liveSearchStyle = "contains",
          liveSearchPlaceholder = "Type here to search",
          virtualScroll = 50
        )
      )
    })

    ## ReactiveValue: selectedTemporalTimeIds ----
    selectedTemporalTimeIds <- reactiveVal(NULL)
    shiny::observeEvent(eventExpr = {
      list(
        input$timeIdChoices_open,
        input$timeIdChoices,
        input$tabs
      )
    }, handlerExpr = {
      if (isFALSE(input$timeIdChoices_open) ||
        !is.null(input$tabs) & !is.null(envir$temporalCharacterizationTimeIdChoices)) {
        selectedTemporalTimeIds(
          envir$temporalCharacterizationTimeIdChoices %>%
            dplyr::filter(.data$temporalChoices %in% input$timeIdChoices) %>%
            dplyr::pull(.data$timeId) %>%
            unique() %>%
            sort()
        )
      }
    })

    cohortSubset <- shiny::reactive({
      return(cohortTable %>%
               dplyr::arrange(.data$cohortId))
    })

    shiny::observe({
      subset <- cohortSubset()$compoundName
      shinyWidgets::updatePickerInput(
        session = session,
        inputId = "targetCohort",
        choicesOpt = list(style = rep_len("color: black;", 999)),
        choices = subset
      )
    })

    shiny::observe({
      subset <- cohortSubset()$compoundName
      shinyWidgets::updatePickerInput(
        session = session,
        inputId = "cohorts",
        choicesOpt = list(style = rep_len("color: black;", 999)),
        choices = subset,
        selected = c(subset[1], subset[2])
      )
    })


    inputCohortIds <- shiny::reactive({
      if (input$tabs == "cohortCounts" |
        input$tabs == "cohortOverlap" |
        input$tabs == "incidenceRate" |
        input$tabs == "timeDistribution") {
        subset <- input$cohorts
      } else {
        subset <- input$targetCohort
      }

      return(subset)
    })

    shiny::observe({
      shinyWidgets::updatePickerInput(
        session = session,
        inputId = paste0("targetCohort", input$tabs),
        choicesOpt = list(style = rep_len("color: black;", 999)),
        choices = inputCohortIds(),
        selected = inputCohortIds()
      )
    })

    shiny::observe({
      shinyWidgets::updatePickerInput(
        session = session,
        inputId = paste0("database", input$tabs),
        choicesOpt = list(style = rep_len("color: black;", 999)),
        choices = selectedDatabaseIds(),
        selected = selectedDatabaseIds()
      )
    })

    shiny::observe({
      subset <- cohortSubset()$compoundName
      shinyWidgets::updatePickerInput(
        session = session,
        inputId = "comparatorCohort",
        choicesOpt = list(style = rep_len("color: black;", 999)),
        choices = subset,
        selected = subset[2]
      )
    })


    # Characterization (Shared across) -------------------------------------------------
    ## Reactive objects ----
    ### getConceptSetNameForFilter ----
    getConceptSetNameForFilter <- shiny::reactive(x = {
      if (!hasData(targetCohortId()) || !hasData(selectedDatabaseIds())) {
        return(NULL)
      }

      jsonExpression <- cohortSubset() %>%
        dplyr::filter(.data$cohortId == targetCohortId()) %>%
        dplyr::select(.data$json)
      jsonExpression <-
        RJSONIO::fromJSON(jsonExpression$json, digits = 23)
      expression <-
        getConceptSetDetailsFromCohortDefinition(cohortDefinitionExpression = jsonExpression)
      if (is.null(expression)) {
        return(NULL)
      }

      expression <- expression$conceptSetExpression %>%
        dplyr::select(.data$name)
      return(expression)
    })


    characterizationOutput <-
      shiny::reactive(x = {
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        progress$set(
          message = paste0(
            "Retrieving characterization output for cohort id ",
            targetCohortId(),
            " cohorts and ",
            length(selectedDatabaseIds()),
            " data sources."
          ),
          value = 0
        )
        data <- getCharacterizationOutput(
          dataSource = dataSource,
          cohortIds = targetCohortId(),
          databaseIds = selectedDatabaseIds(),
          temporalCovariateValueDist = FALSE
        )
        return(data)
      })


    temporalCharacterizationOutput <-
      shiny::reactive(x = {
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        progress$set(
          message = paste0(
            "Retrieving characterization output for target cohort id ",
            targetCohortId(),
            " from ",
            input$database,
            "."
          ),
          value = 0
        )

        if (input$database %in% c(selectedDatabaseIds())) {
          data <- characterizationOutput()
          if (hasData(data$covariateValue)) {
            data$covariateValue <- data$covariateValue %>%
              dplyr::filter(.data$databaseId %in% c(input$database))
          }
          if (hasData(data$covariateValueDist)) {
            data$covariateValueDist <- data$covariateValueDist %>%
              dplyr::filter(.data$databaseId %in% c(input$database))
          }
        } else {
          data <- getCharacterizationOutput(
            dataSource = dataSource,
            cohortIds = targetCohortId(),
            databaseIds = input$database,
            temporalCovariateValueDist = FALSE
          )
        }
        return(data)
      })

    compareCharacterizationOutput <-
      shiny::reactive(x = {
        dataTarget <-
          temporalCharacterizationOutput()
        if (!hasData(dataTarget)) {
          return(NULL)
        }

        progress <- shiny::Progress$new()
        on.exit(progress$close())
        progress$set(
          message = paste0(
            "Retrieving characterization output for comparator cohort id ",
            comparatorCohortId(),
            " from ",
            input$database,
            "."
          ),
          value = 0
        )
        dataComparator <- getCharacterizationOutput(
          dataSource = dataSource,
          cohortIds = c(comparatorCohortId()),
          databaseIds = input$database,
          temporalCovariateValueDist = FALSE
        )
        if (!hasData(dataComparator)) {
          return(NULL)
        }
        data <- NULL
        data$covariateValue <-
          dplyr::bind_rows(
            dataTarget$covariateValue,
            dataComparator$covariateValue
          )
        if (!hasData(data$covariateValue)) {
          data$covariateValue <- NULL
        }
        data$covariateValueDist <-
          dplyr::bind_rows(
            dataTarget$covariateValueDist,
            dataComparator$covariateValueDist
          )
        if (!hasData(data$covariateValueDist)) {
          data$covariateValueDist <- NULL
        }
        return(data)
      })

    shiny::observe({
      subset <- getConceptSetNameForFilter()$name %>%
        sort() %>%
        unique()
      shinyWidgets::updatePickerInput(
        session = session,
        inputId = "conceptSetsSelected",
        choicesOpt = list(style = rep_len("color: black;", 999)),
        choices = subset
      )
    })

    # Infoboxes -------------------
    showInfoBox <- function(title, htmlFileName) {
      shiny::showModal(shiny::modalDialog(
        title = title,
        easyClose = TRUE,
        footer = NULL,
        size = "l",
        HTML(readChar(
          htmlFileName, file.info(htmlFileName)$size
        ))
      ))
    }

    shiny::observeEvent(input$cohortCountsInfo, {
      showInfoBox("Cohort Counts", "html/cohortCounts.html")
    })

    shiny::observeEvent(input$incidenceRateInfo, {
      showInfoBox("Incidence Rate", "html/incidenceRate.html")
    })

    shiny::observeEvent(input$timeDistributionInfo, {
      showInfoBox("Time Distributions", "html/timeDistribution.html")
    })

    shiny::observeEvent(input$conceptsInDataSourceInfo, {
      showInfoBox(
        "Concepts in data source",
        "html/conceptsInDataSource.html"
      )
    })

    shiny::observeEvent(input$orphanConceptsInfo, {
      showInfoBox("Orphan (Source) Concepts", "html/orphanConcepts.html")
    })

    shiny::observeEvent(input$conceptSetDiagnosticsInfo, {
      showInfoBox(
        "Concept Set Diagnostics",
        "html/conceptSetDiagnostics.html"
      )
    })

    shiny::observeEvent(input$inclusionRuleStatsInfo, {
      showInfoBox(
        "Inclusion Rule Statistics",
        "html/inclusionRuleStats.html"
      )
    })

    shiny::observeEvent(input$indexEventBreakdownInfo, {
      showInfoBox("Index Event Breakdown", "html/indexEventBreakdown.html")
    })

    shiny::observeEvent(input$visitContextInfo, {
      showInfoBox("Visit Context", "html/visitContext.html")
    })

    shiny::observeEvent(input$cohortCharacterizationInfo, {
      showInfoBox(
        "Cohort Characterization",
        "html/cohortCharacterization.html"
      )
    })

    shiny::observeEvent(input$temporalCharacterizationInfo, {
      showInfoBox(
        "Temporal Characterization",
        "html/temporalCharacterization.html"
      )
    })

    shiny::observeEvent(input$cohortOverlapInfo, {
      showInfoBox("Cohort Overlap", "html/cohortOverlap.html")
    })

    shiny::observeEvent(input$compareCohortCharacterizationInfo, {
      showInfoBox(
        "Compare Cohort Characteristics",
        "html/compareCohortCharacterization.html"
      )
    })

    selectedCohorts <- shiny::reactive({
      cohorts <- cohortSubset() %>%
        dplyr::filter(.data$cohortId %in% cohortIds()) %>%
        dplyr::arrange(.data$cohortId) %>%
        dplyr::select(.data$compoundName)
      return(apply(cohorts, 1, function(x) {
        tags$tr(lapply(x, tags$td))
      }))
    })

    selectedCohort <- shiny::reactive({
      return(input$targetCohort)
    })

    selectedComparatorCohort <- shiny::reactive({
      return(input$comparatorCohort)
    })

    if ("cohort" %in% enabledTabs) {
      cohortDefinitionsModule(id = "cohortDefinitions",
                              dataSource = dataSource,
                              cohortDefinitions = cohortSubset,
                              cohortTable = cohortTable,
                              databaseTable = databaseTable)
    }

    ### getResolvedConceptsReactive ----
    getResolvedConcepts <-
      shiny::reactive(x = {
        output <-
          resolvedConceptSet(
            dataSource = dataSource,
            databaseIds = as.character(databaseTable$databaseId),
            cohortId = targetCohortId()
          )
        if (!hasData(output)) {
          return(NULL)
        }
        return(output)
      })

    ### getMappedConceptsReactive ----
    getMappedConcepts <-
      shiny::reactive(x = {
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        progress$set(message = "Getting concepts mapped to concept ids resolved by concept set expression (may take time)", value = 0)
        output <-
          mappedConceptSet(
            dataSource = dataSource,
            databaseIds = as.character(databaseTable$databaseId),
            cohortId = targetCohortId()
          )
        if (!hasData(output)) {
          return(NULL)
        }
        return(output)
      })

    getFilteredConceptIds <- shiny::reactive({
      validate(need(hasData(selectedDatabaseIds()), "No data sources chosen"))
      validate(need(hasData(targetCohortId()), "No cohort chosen"))
      validate(need(hasData(conceptSetIds()), "No concept set id chosen"))
      resolved <- getResolvedConcepts()
      mapped <- getMappedConcepts()
      output <- c()
      if (hasData(resolved)) {
        resolved <- resolved %>%
          dplyr::filter(.data$databaseId %in% selectedDatabaseIds()) %>%
          dplyr::filter(.data$cohortId %in% targetCohortId()) %>%
          dplyr::filter(.data$conceptSetId %in% conceptSetIds())
        output <- c(output, resolved$conceptId) %>% unique()
      }
      if (hasData(mapped)) {
        mapped <- mapped %>%
          dplyr::filter(.data$databaseId %in% selectedDatabaseIds()) %>%
          dplyr::filter(.data$cohortId %in% targetCohortId()) %>%
          dplyr::filter(.data$conceptSetId %in% conceptSetIds())
        output <- c(output, mapped$conceptId) %>% unique()
      }
      if (hasData(output)) {
        return(output)
      } else {
        return(NULL)
      }
    })

    if ("includedSourceConcept" %in% enabledTabs) {
      conceptsInDataSourceModule(id = "conceptsInDataSource",
                                 dataSource = dataSource,
                                 selectedCohort = selectedCohort,
                                 selectedDatabaseIds = selectedDatabaseIds,
                                 targetCohortId = targetCohortId,
                                 selectedConceptSets = selectedConceptSets,
                                 getFilteredConceptIds = getFilteredConceptIds,
                                 cohortTable = cohortTable,
                                 databaseTable = databaseTable)
    }

    if ("orphanConcept" %in% enabledTabs) {
      orphanConceptsModule("orphanConcepts",
                           dataSource = dataSource,
                           selectedCohorts = selectedCohorts,
                           selectedDatabaseIds = selectedDatabaseIds,
                           targetCohortId = targetCohortId,
                           selectedConceptSets = selectedConceptSets,
                           conceptSetIds = conceptSetIds)
    }

    if ("cohortCount" %in% enabledTabs) {
      cohortCountsModule(id = "cohortCounts",
                         dataSource = dataSource,
                         cohortTable = cohortTable, # The injection of tables like this should be removed
                         databaseTable = databaseTable, # The injection of tables like this should be removed
                         selectedCohorts = selectedCohorts,
                         selectedDatabaseIds = selectedDatabaseIds,
                         cohortIds = cohortIds)
    }

    if ("inclusionRuleStats" %in% enabledTabs) {
      inclusionRulesModule(id = "inclusionRules",
                           dataSource = dataSource,
                           cohortTable = cohortTable,
                           databaseTable = databaseTable,
                           selectedCohort = selectedCohort,
                           targetCohortId = targetCohortId,
                           selectedDatabaseIds = selectedDatabaseIds)
    }

    if ("indexEventBreakdown" %in% enabledTabs) {
      indexEventBreakdownModule("indexEvents",
                                dataSource = dataSource,
                                selectedCohort = selectedCohort,
                                targetCohortId = targetCohortId,
                                selectedDatabaseIds = selectedDatabaseIds)
    }

    if ("visitContext" %in% enabledTabs) {
      visitContextModule(id = "visitContext",
                         dataSource = dataSource,
                         selectedCohort = selectedCohort,
                         selectedDatabaseIds = selectedDatabaseIds,
                         targetCohortId = targetCohortId,
                         cohortTable = cohortTable,
                         databaseTable = databaseTable)
    }

    if ("relationship" %in% enabledTabs) {
      cohortOverlapModule(id = "cohortOverlap",
                          dataSource = dataSource,
                          selectedCohorts = selectedCohorts,
                          selectedDatabaseIds = selectedDatabaseIds,
                          targetCohortId = targetCohortId,
                          cohortIds = cohortIds,
                          cohortTable = cohortTable)
    }

    if ("temporalCovariateValue" %in% enabledTabs) {
      ### getResolvedAndMappedConceptIdsForFilters ----
      getResolvedAndMappedConceptIdsForFilters <- shiny::reactive({
        validate(need(hasData(selectedDatabaseIds()), "No data sources chosen"))
        validate(need(hasData(targetCohortId()), "No cohort chosen"))
        validate(need(hasData(conceptSetIds()), "No concept set id chosen"))
        resolved <- getResolvedConcepts()
        mapped <- getMappedConcepts()
        output <- c()
        if (hasData(resolved)) {
          resolved <- resolved %>%
            dplyr::filter(.data$databaseId %in% selectedDatabaseIds()) %>%
            dplyr::filter(.data$cohortId %in% targetCohortId()) %>%
            dplyr::filter(.data$conceptSetId %in% conceptSetIds())
          output <- c(output, resolved$conceptId) %>% unique()
        }
        if (hasData(mapped)) {
          mapped <- mapped %>%
            dplyr::filter(.data$databaseId %in% selectedDatabaseIds()) %>%
            dplyr::filter(.data$cohortId %in% targetCohortId()) %>%
            dplyr::filter(.data$conceptSetId %in% conceptSetIds())
          output <- c(output, mapped$conceptId) %>% unique()
        }
        if (hasData(output)) {
          return(output)
        } else {
          return(NULL)
        }
      })

      timeDistributionsModule(id = "timeDistributions",
                              dataSource = dataSource,
                              selectedCohorts = selectedCohorts,
                              cohortIds = cohortIds,
                              selectedDatabaseIds = selectedDatabaseIds,
                              cohortTable = cohortTable,
                              databaseTable = databaseTable)

      characterizationModule(id = "characterization",
                             dataSource = dataSource,
                             cohortTable = cohortTable,
                             databaseTable = databaseTable,
                             selectedCohort = selectedCohort,
                             selectedDatabaseIds = selectedDatabaseIds,
                             targetCohortId = targetCohortId,
                             temporalAnalysisRef = envir$temporalAnalysisRef,
                             analysisNameOptions = envir$analysisNameOptions,
                             analysisIdInCohortCharacterization = envir$analysisIdInCohortCharacterization,
                             getResolvedAndMappedConceptIdsForFilters = getResolvedAndMappedConceptIdsForFilters,
                             selectedConceptSets = selectedConceptSets,
                             characterizationMenuOutput = characterizationOutput, # This name must be changed
                             characterizationTimeIdChoices = envir$characterizationTimeIdChoices)


      temporalCharacterizationModule(id = "temporalCharacterization",
                                     dataSource = dataSource,
                                     databaseTable = databaseTable,
                                     selectedCohort = selectedCohort,
                                     selectedDatabaseIds = selectedDatabaseIds,
                                     targetCohortId = targetCohortId,
                                     temporalAnalysisRef = envir$temporalAnalysisRef,
                                     analysisNameOptions = envir$analysisNameOptions,
                                     selectedTemporalTimeIds = selectedTemporalTimeIds,
                                     getResolvedAndMappedConceptIdsForFilters = getResolvedAndMappedConceptIdsForFilters,
                                     selectedConceptSets = selectedConceptSets,
                                     analysisIdInTemporalCharacterization = envir$analysisIdInTemporalCharacterization,
                                     domainIdOptions = envir$domainIdOptions,
                                     temporalCharacterizationTimeIdChoices = envir$temporalCharacterizationTimeIdChoices,
                                     characterizationOutputForCharacterizationMenu = characterizationOutput)

      compareCohortCharacterizationModule("compareCohortCharacterization",
                                          dataSource = dataSource,
                                          selectedCohort = selectedCohort,
                                          selectedDatabaseIds = selectedDatabaseIds,
                                          targetCohortId = targetCohortId,
                                          comparatorCohortId = comparatorCohortId,
                                          selectedComparatorCohort = selectedComparatorCohort,
                                          selectedConceptSets = selectedConceptSets,
                                          selectedTimeIds = shiny::reactive({ c(envir$characterizationTimeIdChoices$timeId %>% unique(), NA) }),
                                          characterizationOutputMenu = compareCharacterizationOutput,
                                          getFilteredConceptIds = getFilteredConceptIds,
                                          cohortTable = cohortTable,
                                          databaseTable = databaseTable,
                                          temporalAnalysisRef = envir$temporalAnalysisRef,
                                          analysisIdInCohortCharacterization = envir$analysisIdInCohortCharacterization,
                                          analysisNameOptions = envir$analysisNameOptions,
                                          domainIdOptions = envir$domainIdOptions,
                                          characterizationTimeIdChoices = envir$characterizationTimeIdChoices,
                                          temporalChoices = envir$temporalChoices,
                                          prettyTable1Specifications = envir$prettyTable1Specifications)

      compareCohortCharacterizationModule("compareTemporalCohortCharacterization",
                                          dataSource = dataSource,
                                          selectedCohort = selectedCohort,
                                          selectedDatabaseIds = selectedDatabaseIds,
                                          targetCohortId = targetCohortId,
                                          comparatorCohortId = comparatorCohortId,
                                          selectedComparatorCohort = selectedComparatorCohort,
                                          selectedConceptSets = selectedConceptSets,
                                          selectedTimeIds = selectedTemporalTimeIds,
                                          characterizationOutputMenu = compareCharacterizationOutput,
                                          getFilteredConceptIds = getFilteredConceptIds,
                                          cohortTable = cohortTable,
                                          databaseTable = databaseTable,
                                          temporalAnalysisRef = envir$temporalAnalysisRef,
                                          analysisIdInCohortCharacterization = envir$analysisIdInCohortCharacterization,
                                          analysisNameOptions = envir$analysisNameOptions,
                                          domainIdOptions = envir$domainIdOptions,
                                          characterizationTimeIdChoices = envir$characterizationTimeIdChoices,
                                          temporalChoices = envir$temporalChoices,
                                          prettyTable1Specifications = envir$prettyTable1Specifications)
    }

    if ("incidenceRate" %in% enabledTabs) {
      incidenceRatesModule(id = "incidenceRates",
                           dataSource = dataSource,
                           selectedCohorts = selectedCohorts,
                           cohortIds = cohortIds,
                           selectedDatabaseIds = selectedDatabaseIds,
                           cohortTable = cohortTable)
    }

    databaseInformationModule(id = "databaseInformation",
                              dataSource = dataSource,
                              selectedDatabaseIds = selectedDatabaseIds,
                              databaseMetadata = envir$databaseMetadata)

  })

}