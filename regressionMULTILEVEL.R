library(devtools)
source_url("https://raw.githubusercontent.com/nadyaeiou/nadyasscripts/main/all.R")
source_url("https://raw.githubusercontent.com/nadyaeiou/nadyasscripts/main/regressionINTEXT.R")

##########

cat("\n####################")
cat("\nLoading Nadya's multilevel modelling upgrades from Github.")
cat("\n            Version : 0.0.0.9000")
cat("\n        Last update : 14 Dec 2020, 6:02am")
cat("\n Loading Package(s) : lme4, lmerTest")
cat("\nRequired Package(s) : effectsize")
cat("\n")

starttime <- Sys.time()

##########



library(lme4); library(lmerTest)



mlm <- function(
  formula.lmer, data, REML = FALSE, switch_optimiser = FALSE,
  confint = NULL, std = FALSE, round = 5,
  debug = FALSE) {
  
  if(is.character(formula.lmer)) {formula.lmer = as.formula(formula.lmer)}
  
  # fix for convergence errors
  optimiser.switch = lmerControl(optimizer = "Nelder_Mead", optCtrl = list(maxfun = 10000000))
  if(switch_optimiser) {cat("Using Nelder-Mead optimisation with maximum 10,000,000 evaluations\ninstead of default nloptwrap.\n\n")}
  
  # run multilevel and summarise
  if(switch_optimiser) {lmer.output = lmer(formula.lmer, data = data, REML = REML, control = optimiser.switch)}
  else {lmer.output = lmer(formula.lmer, data = data, REML = REML)}
  lmer.summary = summary(lmer.output)
  
  # extract random effects and conduct significance testing using lmerTest::rand
  randomeffects = VarCorr(lmer.output) %>% as.data.frame() %>%
    dplyr::filter(is.na(var2)) %>%
    dplyr::mutate(
      variable = paste0(var1, " | ", grp),
      var = (sdcor * sdcor) %>% round(round),
      p = c(NA, lmerTest::rand(lmer.output)[2, "Pr(>Chisq)"] %>% round(3), NA),
      sig = sigstars(p),
      .keep = "none"
    )
  randomeffects[nrow(randomeffects), "variable"] = "Residual"
  
  # extract fixed effects
  fixedeffects = lmer.summary[["coefficients"]] %>% as.data.frame() %>%
    dplyr::mutate(
      variable = rownames(.),
      coeff = Estimate %>% round(round),
      se = `Std. Error` %>% round(round),
      p = `Pr(>|t|)` %>% round(3),
      sig = sigstars(p),
      .keep = "none"
    )
  
  # add std coeffs if requested
  if(std) {
    cat("Standardised coeffs calculated at level 1.\n\n")
    if(switch_optimiser) {}
    else {std.output = lmer(formula.lmer, data = effectsize::standardize(data), REML = REML)}
    
    # random effects
    std.random = VarCorr(std.output) %>% as.data.frame() %>%
      dplyr::filter(is.na(var2)) %>%
      dplyr::mutate(
        variable = paste0(var1, " | ", grp),
        stdvar = (sdcor * sdcor) %>% round(round),
        .keep = "none"
      )
    std.random[nrow(std.random), "variable"] = "Residual"
    randomeffects = merge(std.random, randomeffects, sort = FALSE)
    
    # fixed effects
    std.summary = std.output %>% summary()
    std.fixed = data.frame(std.summary[["coefficients"]]) %>%
      dplyr::mutate(
        variable = rownames(.),
        stdcoeff = Estimate %>% round(round),
        .keep = "none"
      )
    fixedeffects = merge(std.fixed, fixedeffects, sort = FALSE)
    fixedeffects[1, "stdcoeff"] = NA
  }
  
  # extract confints (unstd)
  if(!is.null(confint)) {
    ci = confint(lmer.output, parm = confint, oldNames = FALSE) %>%
      as.data.frame() %>%
      dplyr::mutate(
        variable = rownames(.),
        CI95lower = `2.5 %` %>% round(round),
        CI95upper = `97.5 %` %>% round(round),
        .keep = 'none'
      )
    # add to fixed effects table and undo reordering
    originalorder = fixedeffects$variable
    fixedeffects = merge(fixedeffects, ci, all.x = TRUE, sort = FALSE) %>%
      dplyr::slice(match(originalorder, variable))
  }
  
  if(debug) {print(randomeffects)}
  if(debug) {print(fixedeffects)}
  
  return(list(random = randomeffects, fixed = fixedeffects))
}



mlm.hierarchical <- function(
  formulae, data, intext_specific = NULL, viewtable = TRUE, csv = NULL, print = TRUE,
  REML = FALSE, switch_optimiser = FALSE, confint = NULL, std = FALSE, round = 5, debug = FALSE) {
  
  if(!is.data.frame(data)) stop("Data should be of class data.frame.")
  if(!is.null(csv)) {
    if(grepl(".csv", csv)) stop("You have indicated that you want a .csv output. Please ensure your filename (passed to csv argument) DOES NOT have any format ending (including .csv). If you do not want a .csv output, omit the csv argument.")
  }
  
  if(!is.null(intext_specific)) {
    for(variable in intext_specific) {
      if(!(variable %in% confint)) {
        confint = c(variable, confint)
      }
    }
  }
  
  # get number of models
  num_of_models = length(formulae)
  
  # initialise list of results
  results = list()
  
  # run regression for each model
  for(n in 1:num_of_models) {
    
    # prepare model label
    label = paste0("m", n)
    
    # retrieve current formula
    current_formula = formulae[[n]]
    
    # run regression for current model
    current_result = mlm(
      formula.lmer = current_formula, data = data,
      REML = REML, switch_optimiser = switch_optimiser,
      confint = confint, std = std, round = round)
    
    # relabel columns
    colnames(current_result$random)[-1] = paste0(label, "_", colnames(current_result$random)[-1])
    colnames(current_result$fixed)[-1] = paste0(label, "_", colnames(current_result$fixed)[-1])
    if(debug) {print(current_result)}
    
    # add results to list
    results[[label]] = current_result
  }
  
  # if user wants to view table of outputs side by side
  # or if user wants to write csv
  # prepare table and execute accordingly
  if(viewtable | !is.null(csv)) {
    for(effect in c("random", "fixed")) {
      table_of_outputs = results[[1]][[effect]]
      for(n in 2:num_of_models) {table_of_outputs = merge(table_of_outputs, results[[n]][[effect]], all = T, sort = F)}
      if(viewtable) {View(table_of_outputs)}
      if(!is.null(csv)) {write.csv(table_of_outputs, paste0(csv, "_", effect, ".csv", sep = ""), row.names = F)}
    }
  }
  
  # if user wants to see printed list, print it
  if(print) {print(results)}
  
  # if user wants to see intext, print it
  if(!is.null(intext_specific)) {
    for(variable in intext_specific) {
      for(n in 1:num_of_models) {
        res = results[[n]][["fixed"]]
        cat(intext_regression(regression.output = res, varname = variable, round = round), "\n")
      }
    }
  }
  
  # silently return list
  invisible(results)
}



##########

endtime <- Sys.time()
cat("\nFinished loading Nadya's multilevel modelling upgrades upgrades.")
cat("\nTime taken :", (endtime - starttime))
cat("\n! NOTE ! Please cite lme4 (conducting multilevel) and lmerTest (significance testing) in your manuscript.")
cat("\n####################")
cat("\n")

rm(starttime); rm(endtime)