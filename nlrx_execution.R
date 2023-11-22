if (!require("nlrx")) install.packages("nlrx")
if (!require("dplyr")) install.packages("dplyr")
library(nlrx)
library(dplyr)

#file.choose()
netlogopath <- file.path("C:\\Program Files\\NetLogo 6.3.0")
modelpath <- file.path("C:\\Users\\carst\\OneDrive\\Master_EES\\Masterarbeit\\Netlogo\\MA_Simulation\\2023_ihte_v5.nlogo")
outpath <- file.path("C:\\Users\\carst\\OneDrive\\Master_EES\\Masterarbeit\\Netlogo\\MA_Simulation\\Results")

nl <- nl(nlversion = "6.3.0",
          nlpath = netlogopath,
          modelpath = modelpath)

nl@experiment <- experiment(
  expname = "experiment",
  outpath = outpath,
  repetition = 10,
  tickmetrics = "false",
  idsetup = "setup",
  idgo = "go",
  runtime = 25,
  evalticks = NA_integer_,
  metrics = c("(count turtles with [tax-decision = 0]/(count turtles))",
                   "(count turtles with [tax-decision = 1]/(count turtles))"),
  metrics.turtles = list("turtles" = c("tax-morale",
                                       "income",
                                       "normalized-income",
                                       "income-group",
                                       "taxable-income",
                                       "tax-burden",
                                       "tax-rate",
                                       "link-count",
                                       #"tax-morale",
                                       "tax-decision",
                                       "tax-reputation",
                                       "payoff-taxes",
                                       "payoff-evasion",
                                       "social-tax-morale",
                                       "decision-threshold"
                                       )),
  constants = list(
    "networksize" = 5,
    "randomSeed?" = "true",
    "detectionpunishment" = 0.35,
    "updatingshare" = 0.5,
    "z-score?" = "false",
    "num-individuals" = 10000,
    "reputationweight" = 0.5,
    "socialweight" = 0.5,
    #"homophilystrength" = 0.73,
    "manual-seed" = -125478),
  variables = list(
    "homophilystrength" = list(
      values = c(0, 0.25, 0.5, 0.75, 1), 
      min = 0,
      max = 1,
      step = 0.25,
      qfun = "qunif")
  )
)

nl@simdesign <- simdesign_distinct(nl = nl,
                                   nseed = 1)

result <- run_nl_all(nl = nl)


df <- data.frame(
  run = as.factor(result$`[run number]`),
  class = homophilystrength <- as.factor(result$homophilystrength),
  evading = evading <- result$`(count turtles with [tax-decision = 0]/(count turtles))`,
  paying = result$`(count turtles with [tax-decision = 1]/(count turtles))`
)


means <- aggregate(df$evading, list(df$class), mean)

table <- table(means)

print(table)








