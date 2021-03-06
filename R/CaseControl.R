# @file CaseControl.R
#
# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of MethodsLibraryPleEvaluation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' @export
runCaseControl <- function(connectionDetails,
                           cdmDatabaseSchema,
                           oracleTempSchema = NULL,
                           outcomeDatabaseSchema = cdmDatabaseSchema,
                           outcomeTable = "cohort",
                           exposureDatabaseSchema = cdmDatabaseSchema,
                           exposureTable = "drug_era",
                           nestingCohortDatabaseSchema = cdmDatabaseSchema,
                           nestingCohortTable = "condition_era",
                           outputFolder,
                           cdmVersion = "5",
                           maxCores = 4) {
    start <- Sys.time()

    ccFolder <- file.path(outputFolder, "caseControl")
    if (!file.exists(ccFolder))
        dir.create(ccFolder)

    ccSummaryFile <- file.path(outputFolder, "ccSummary.rds")
    if (!file.exists(ccSummaryFile)) {
        allControls <- read.csv(file.path(outputFolder , "allControls.csv"))
        allControls <- unique(allControls[, c("targetId", "outcomeId", "nestingId")])
        eonList <- list()
        for (i in 1:nrow(allControls)) {
            eonList[[length(eonList) + 1]] <- CaseControl::createExposureOutcomeNestingCohort(exposureId = allControls$targetId[i],
                                                                                            outcomeId = allControls$outcomeId[i],
                                                                                            nestingCohortId = allControls$nestingId[i])
        }
        ccAnalysisListFile <- system.file("settings", "ccAnalysisSettings.txt", package = "MethodsLibraryPleEvaluation")
        ccAnalysisList <- CaseControl::loadCcAnalysisList(ccAnalysisListFile)
        ccResult <- CaseControl::runCcAnalyses(connectionDetails = connectionDetails,
                                               cdmDatabaseSchema = cdmDatabaseSchema,
                                               oracleTempSchema = oracleTempSchema,
                                               exposureDatabaseSchema = exposureDatabaseSchema,
                                               exposureTable = exposureTable,
                                               outcomeDatabaseSchema = outcomeDatabaseSchema,
                                               outcomeTable = outcomeTable,
                                               nestingCohortDatabaseSchema = nestingCohortDatabaseSchema,
                                               nestingCohortTable = nestingCohortTable,
                                               ccAnalysisList = ccAnalysisList,
                                               exposureOutcomeNestingCohortList = eonList,
                                               outputFolder = ccFolder,
                                               compressCaseDataFiles = TRUE,
                                               prefetchExposureData = TRUE,
                                               getDbCaseDataThreads = min(3, maxCores),
                                               selectControlsThreads = min(3, maxCores),
                                               getDbExposureDataThreads = min(3, maxCores),
                                               createCaseControlDataThreads = min(5, maxCores),
                                               fitCaseControlModelThreads = min(5, maxCores),
                                               cvThreads = min(2,maxCores))

        ccSummary <- CaseControl::summarizeCcAnalyses(ccResult, ccFolder)
        saveRDS(ccSummary, ccSummaryFile)
    }
    delta <- Sys.time() - start
    writeLines(paste("Completed case-control analyses in", signif(delta, 3), attr(delta, "units")))
}

#' @export
createCaseControlSettings <- function(fileName) {

    getDbCaseDataArgs1 <- CaseControl::createGetDbCaseDataArgs(useNestingCohort = FALSE,
                                                               getVisits = FALSE,
                                                               maxNestingCohortSize = 1e8,
                                                               maxCasesPerOutcome = 1e6)

    selectControlsArgs1 <- CaseControl::createSelectControlsArgs(firstOutcomeOnly = TRUE,
                                                                 washoutPeriod = 365,
                                                                 controlsPerCase = 2,
                                                                 matchOnAge = TRUE,
                                                                 ageCaliper = 2,
                                                                 matchOnGender = TRUE,
                                                                 matchOnProvider = FALSE,
                                                                 matchOnVisitDate = FALSE)

    getDbExposureDataArgs <-  CaseControl::createGetDbExposureDataArgs()

    createCaseControlDataArgs1 <- CaseControl::createCreateCaseControlDataArgs(firstExposureOnly = FALSE,
                                                                               riskWindowStart = 0,
                                                                               riskWindowEnd = 0,
                                                                               exposureWashoutPeriod = 365)

    fitCaseControlModelArgs1 <-  CaseControl::createFitCaseControlModelArgs()

    ccAnalysis1 <- CaseControl::createCcAnalysis(analysisId = 1,
                                                 description = "2 controls per case",
                                                 getDbCaseDataArgs = getDbCaseDataArgs1,
                                                 selectControlsArgs = selectControlsArgs1,
                                                 getDbExposureDataArgs = getDbExposureDataArgs,
                                                 createCaseControlDataArgs = createCaseControlDataArgs1,
                                                 fitCaseControlModelArgs = fitCaseControlModelArgs1)

    selectControlsArgs2 <- CaseControl::createSelectControlsArgs(firstOutcomeOnly = TRUE,
                                                                 washoutPeriod = 365,
                                                                 controlsPerCase = 10,
                                                                 matchOnAge = TRUE,
                                                                 ageCaliper = 2,
                                                                 matchOnGender = TRUE,
                                                                 matchOnProvider = FALSE,
                                                                 matchOnVisitDate = FALSE)

    ccAnalysis2 <- CaseControl::createCcAnalysis(analysisId = 2,
                                                 description = "10 controls per case",
                                                 getDbCaseDataArgs = getDbCaseDataArgs1,
                                                 selectControlsArgs = selectControlsArgs2,
                                                 getDbExposureDataArgs = getDbExposureDataArgs,
                                                 createCaseControlDataArgs = createCaseControlDataArgs1,
                                                 fitCaseControlModelArgs = fitCaseControlModelArgs1)

    getDbCaseDataArgs2 <- CaseControl::createGetDbCaseDataArgs(useNestingCohort = TRUE,
                                                               getVisits = FALSE,
                                                               maxNestingCohortSize = 1e8,
                                                               maxCasesPerOutcome = 1e6)

    ccAnalysis3 <- CaseControl::createCcAnalysis(analysisId = 3,
                                                 description = "Nesting in indication, 2 controls per case",
                                                 getDbCaseDataArgs = getDbCaseDataArgs2,
                                                 selectControlsArgs = selectControlsArgs1,
                                                 getDbExposureDataArgs = getDbExposureDataArgs,
                                                 createCaseControlDataArgs = createCaseControlDataArgs1,
                                                 fitCaseControlModelArgs = fitCaseControlModelArgs1)

    ccAnalysis4 <- CaseControl::createCcAnalysis(analysisId = 4,
                                                 description = "Nesting in indication, 10 controls per case",
                                                 getDbCaseDataArgs = getDbCaseDataArgs2,
                                                 selectControlsArgs = selectControlsArgs2,
                                                 getDbExposureDataArgs = getDbExposureDataArgs,
                                                 createCaseControlDataArgs = createCaseControlDataArgs1,
                                                 fitCaseControlModelArgs = fitCaseControlModelArgs1)

    ccAnalysisList <- list(ccAnalysis1, ccAnalysis2, ccAnalysis3, ccAnalysis4)

    if (!missing(fileName) && !is.null(fileName)) {
        CaseControl::saveCcAnalysisList(ccAnalysisList, fileName)
    }
    invisible(ccAnalysisList)
}
