if (!require("nlrx")) install.packages("nlrx")
library(nlrx)

#file.choose()
netlogopath <- file.path("C:\\Program Files\\NetLogo 6.3.0")
modelpath <- file.path("C:\Netlogo\\MA_Simulation\\2023_ihte_v5.nlogo")
outpath <- file.path("C:\\Netlogo\\MA_Simulation\\Results")

nl <- nl(nlversion = "6.3.0",
          nlpath = netlogopath,
          modelpath = modelpath)

nl@experiment <- experiment(
  expname = "experiment",
  outpath = outpath,
  repetition = 1,
  tickmetrics = "true",
  idsetup = "setup",
  idgo = "go",
  runtime = 50,
  evalticks = NA_integer_,
  metrics = c("(count turtles with [tax-decision = 0]/(count turtles))",
                   "(count turtles with [tax-decision = 1]/(count turtles))"),
  metrics.turtles = list("turtles" = c("tax-morale")),
  constants = list(
    "networksize" = 5,
    "randomSeed?" = "true",
    "detectionpunishment" = 0.35,
    "updatingshare" = 0.25,
    "z-score?" = "false",
    "num-individuals" = 1000,
    "reputationweight" = 0.5,
    "socialweight" = 0.5,
    "homophilystrength" = 0.73,
    "manual-seed" = -125478)
)

nl@simdesign <- simdesign_simple(nl = nl, nseeds = 1)

result <- run_nl_all(nl = nl)
