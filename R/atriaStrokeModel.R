#' Apply the existing model Atria stroke risk using the standardised framework
#'
#' @details
#' This function applies Atria stroke risk to a target cohort and validates the performance
# using the outcome cohort
#'
#' @param connectionDetails                The connection details for extracting the data
#' @param cdmDatabaseSchema                      A string specifying the database containing the cdm
#' @param cohortDatabaseSchema                    A string specifying the database containing the target population cohort
#' @param outcomeDatabaseSchema                   A string specifying the database containing the outcome cohort
#' @param cohortTable          A string specifying the table containing the target population cohort
#' @param outcomeTable        A string specifying the table containing the outcome cohort
#' @param cohortId             An iteger specifying the cohort id for the target population cohorts
#' @param outcomeId          An iteger specifying the cohort id for the outcome cohorts
#' @param oracleTempSchema   The temp schema require is using oracle
#' @param riskWindowStart    The start of the period to predict the risk of the outcome occurring start relative to the target cohort start date
#' @param riskWindowEnd      The end of the period to predict the risk of the outcome occurring start relative to the target cohort start date
#' @param requireTimeAtRisk  Require a minimum number of days observed in the time at risk period?
#' @param minTimeAtRisk      If requireTimeAtRisk is true, the minimum number of days at risk
#' @param includeAllOutcomes  Whether to include people with outcome who do not satify the minTimeAtRisk
#' @param removePriorOutcome  Remove people with prior outcomes from the target population
#' @param calibrationPopulation A data.frame of subjectId, cohortStartDate, indexes used to recalibrate the model on new data
#'
#' @return
#' A list containing the model performance and the personal predictions for each subject in the target population
#'
#' @export
atriaStrokeModel <- function(connectionDetails,
                         cdmDatabaseSchema,
                         cohortDatabaseSchema,
                         outcomeDatabaseSchema,
                         cohortTable,
                         outcomeTable,
                         cohortId,
                         outcomeId,
                         oracleTempSchema=NULL,
                         riskWindowStart = 1,
                         riskWindowEnd = 365,
                         requireTimeAtRisk = T,
                         minTimeAtRisk = 364,
                         includeAllOutcomes = T,
                         removePriorOutcome = T,
                         calibrationPopulation=NULL){

  #input checks...
  if(missing(connectionDetails))
    stop('Need to enter connectionDetails')
  if(missing(cdmDatabaseSchema))
    stop('Need to enter cdmDatabaseSchema')
  if(missing(cohortDatabaseSchema))
    stop('Need to enter cohortDatabaseSchema')
  if(missing(outcomeDatabaseSchema))
    stop('Need to enter outcomeDatabaseSchema')
  if(missing(cohortTable))
    stop('Need to enter cohortTable')
  if(missing(outcomeTable))
    stop('Need to enter outcomeTable')
  if(missing(cohortId))
    stop('Need to enter cohortId')
  if(missing(outcomeId))
    stop('Need to enter outcomeId')
  if(!is.null(calibrationPopulation)){
    if(sum(c('subjectId','cohortStartDate','indexes')%in%colnames(calibrationPopulation))!=3){
      stop("Need 'subjectId','cohortStartDate','indexes' in data.frame")
    }
    calibrationPopulation <- calibrationPopulation[,c('subjectId','cohortStartDate','indexes')]
  }

  conceptSets <- system.file("extdata", "existingStrokeModels_concepts.csv", package = "PredictionComparison")
  conceptSets <- read.csv(conceptSets)

  existingBleedModels <- system.file("extdata", "existingStrokeModels_modelTable.csv", package = "PredictionComparison")
  existingBleedModels <- read.csv(existingBleedModels)

  modelNames <- system.file("extdata", "existingStrokeModels_models.csv", package = "PredictionComparison")
  modelNames <- read.csv(modelNames)

  modelTable <- existingBleedModels[existingBleedModels$modelId==modelNames$modelId[modelNames$name=='Atria'],]
  modelTable <- modelTable[,c('modelId','modelCovariateId','coefficientValue')]

  # use history anytime prior by setting long term look back to 9999
  covariateSettings <- FeatureExtraction::createCovariateSettings(useDemographicsAgeGroup  = T,
                                                                  useDemographicsGender = T,
                                                                  useConditionOccurrenceLongTerm = T,
                                                                  useConditionGroupEraLongTerm = T,
                                                                  longTermStartDays = -365*5)

  result <- PatientLevelPrediction::evaluateExistingModel(modelTable = modelTable,
                                                          covariateTable = conceptSets[,c('modelCovariateId','covariateId')],
                                                          interceptTable = NULL,
                                                          type = 'score',
                                                          covariateSettings = covariateSettings,
                                                          riskWindowStart = riskWindowStart,
                                                          riskWindowEnd = riskWindowEnd,
                                                          requireTimeAtRisk = requireTimeAtRisk,
                                                          minTimeAtRisk = minTimeAtRisk,
                                                          includeAllOutcomes = includeAllOutcomes,
                                                          removeSubjectsWithPriorOutcome =removePriorOutcome,
                                                          connectionDetails = connectionDetails,
                                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                                          cohortTable = cohortTable,
                                                          cohortId = cohortId,
                                                          outcomeDatabaseSchema = outcomeDatabaseSchema,
                                                          outcomeTable = outcomeTable,
                                                          outcomeId = outcomeId,
                                                          calibrationPopulation=calibrationPopulation)

  inputSetting <- list(connectionDetails=connectionDetails,
                       cdmDatabaseSchema=cdmDatabaseSchema,
                       cohortDatabaseSchema=cohortDatabaseSchema,
                       outcomeDatabaseSchema=outcomeDatabaseSchema,
                       cohortTable=cohortTable,
                       outcomeTable=outcomeTable,
                       cohortId=cohortId,
                       outcomeId=outcomeId,
                       oracleTempSchema=oracleTempSchema)
  result <- list(model=list(model='atriaStroke'),
                 analysisRef ='000000',
                 inputSetting =inputSetting,
                 executionSummary = 'Not available',
                 prediction=result$prediction,
                 performanceEvaluation=result$performance)
  class(result$model) <- 'plpModel'
  attr(result$model, "type")<- 'existing model'
  class(result) <- 'runPlp'
  return(result)
}
