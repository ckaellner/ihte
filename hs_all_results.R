# Installation of Packages
{
  if (!require("tseries")) install.packages("tseries")
  if (!require("dplyr")) install.packages("dplyr")
  if (!require("rlist")) install.packages("rlist")
  if (!require("modelbased")) install.packages("modelbased")
  if (!require("ggplot2")) install.packages("ggplot2")
  if (!require("ggpubr")) install.packages("ggpubr")
  
  library(tseries)
  library(dplyr)
  library(rlist)
  library(modelbased)
  library(ggplot2)
  library(ggpubr)
}

# Simualtion values
data <- h1_results
data$evasionshare <- data$`(count turtles with [tax-decision = 1])/(count turtles)`

ticks <- max(data$`[step]` ) + 1
runs <- length(data$`[run number]`)/ticks
num_individuals <- max(data$`num-individuals`)

# Convergence Test
{
  # Macro Level
  {
    # augment Dickey-Fuller Test
    aDF_macro <- data.frame(
      homophilystrength = logical(),
      aDF_parameter = logical(),
      aDF_p.value = logical())
    
    for (i in 1:runs){
      first_tick <- i * ticks - ticks + 1
      last_tick <- first_tick + ticks - 1
      
      aDF_macro_testdata <- data$evasionshare[first_tick:last_tick]
      aDF_macro_testresult <- adf.test(aDF_macro_testdata)
      
      aDF_row_test <- list(data$homophilystrength[first_tick],
                        aDF_macro_testresult$statistic,
                        aDF_macro_testresult$p.value)
      
      aDF_macro <- rbind(aDF_macro,
                         aDF_row_test)
    }
  }
  
  # Micro Level
  {
    # Tax Morale Data on Micro Level
    {
      tax_morale <- c()
      
      for (i in 1:runs){
        first_tick <- i * ticks - ticks + 1
        last_tick <- first_tick + ticks - 1
        
        tax_morale_rows <- c()
        
        for (j in first_tick:last_tick){
          selected_row <- data$metrics.turtles[[j]] %>% pull(2)
          tax_morale_rows <- cbind(tax_morale_rows, selected_row)
        }
        
        tax_morale <- rbind(tax_morale, tax_morale_rows)
      }
      
      tax_morale <- unname(tax_morale)
    }
    
    # augmented Dickey-Fuller Test on Micro Level
    # limited to 10.000 tests
    {
      aDF_micro <- data.frame(
        homophilystrength = logical(),
        aDF_parameter = logical(),
        aDF_p.value = logical())
      
      sample_rows <- sample(1:nrow(tax_morale), 10000, replace = TRUE)
      
      for (i in 1:length(sample_rows)){
        sampled_row <- sample_rows[i]
        aDF_micro_testresult <- adf.test(tax_morale[sampled_row,])
        
        aDF_row_test <- list(data$homophilystrength[sampled_row],
                             aDF_micro_testresult$statistic,
                             aDF_micro_testresult$p.value)
        
        aDF_micro <- rbind(aDF_micro,
                           aDF_row_test)
      }
    }

  }
}

# Convergence Rate
{
  # Dickey Fuller variant
  {
    # Macro Level
    {
    ssd_macro <- data.frame(homophilystrength = logical(),
                            ssd = logical())
    
    for (i in 1:runs){
      first_tick <- i * ticks - ticks + 1
      last_tick <- first_tick + ticks - 1
      
      conv_rate <- list(data$homophilystrength[first_tick],
                        sum(diff(data$evasionshare[first_tick:last_tick])^2))
      
      ssd_macro <- rbind(ssd_macro,
                         unname(conv_rate))
    }
    }
  
    # Micro Level
    {
    ssd_micro <- data.frame(homophilystrength = logical(),
                            ssd = logical())
    
    sample_row <- sample(1:nrow(tax_morale), 10000, replace = TRUE)
    
    for (i in 1:length(sample_row)){
      sampled_row <- sample_row[i]
      conv_rate <- list(data$homophilystrength[(sampled_row/ticks)],
                        sum(diff(tax_morale[sampled_row,])^2))
      
      ssd_micro <- rbind(ssd_micro, conv_rate)
    }
  }
  }
  
  # Macro Level: Smoothing & Threshold
  {
    threshold_conv <- 0.025
    
    conv_tick <- data.frame(logical(),logical())
    
    for (i in 1:runs){
      conv_row <- logical()
      first_tick <- i * ticks - ticks + 2
      last_tick <- first_tick + 49
      evasion_data <- data$evasionshare[first_tick:last_tick]
      
      for (j in 1:length(evasion_data - 1)){
        conv_row[j] <- abs(evasion_data[j + 1] - 
                             evasion_data[j]) / evasion_data[j + 1]
      }
      conv_row <- smooth(conv_row)
      conversion_tick <- which(conv_row < threshold_conv)
      threshold_tick <- data.frame(data$homophilystrength[[first_tick]], 
                          threshold_tick[1])
      
      conv_tick <- rbind(conv_tick, unname(threshold_tick))
                         
    }
    
  }
  
  # Micro Level: Smoothing & Threshold
  {
    threshold_conv <- 0.01
    
    tax_morale <- tax_morale[,-c(1)]
    
    tax_morale_without0 <- apply(tax_morale, 1, function(row) all(row !=0 ))
    tax_morale_without0 <- which(tax_morale_without0 == TRUE)
    tax_morale_without0 <- tax_morale[tax_morale_without0,]
    
    sample_row <- sample(1:nrow(tax_morale_without0), 10000, replace = TRUE)
    
    conv_data <- logical()
    conv_threshold <- data.frame(row_num = logical(),
                                 homophilystrength = logical(),
                                 conv_point = logical())
    
    for (i in 1:length(sample_row)){
      sampled_row <- sample_row[i]
      conv_row <- logical()
      
      for (j in 1:length(tax_morale_without0[sampled_row,]) - 1){
        conv_row[j] <- abs(tax_morale_without0[sampled_row, j + 1] - tax_morale_without0[sampled_row, j ]) / tax_morale_without0[sampled_row, j ]
      }
      conv_row <- smooth(conv_row)
      conv_data <- rbind(conv_data, conv_row)
      threshold_tick <- which(conv_row < threshold_conv)
      hs_num <- sample_row[i]/num_individuals
      threshold_data <- c(sampled_row,
                             data$homophilystrength[hs_num],
                             threshold_tick[1])
      conv_threshold <- rbind(conv_threshold,threshold_data)
    }
    
    conv_threshold <- na.omit(conv_threshold)
    
    conv_threshold <- subset(conv_threshold, X14 < 51)
    #conv_threshold %>% group_by(as.factor(X1)) %>% summarise (mean = mean(X22))
    
  }
  
  # Plot
  {
    
  }

}

# Tax Evasion by income group and homophily strength
{
  data_last_ticks <- data.frame(hs_strength = logical(),
                                run = logical(),
                                income_group = logical(),
                                tax_decision = logical())
  
    for (i in 1:runs){
      tick <- i * 51
      selected_data <- data.frame(data$homophilystrength[tick],
                                  i,
                                  data$metrics.turtles[[tick]][,6],
                                  data$metrics.turtles[[tick]][,11])
      data_last_ticks <- rbind(data_last_ticks, selected_data)
    }
  
  evasionshare_by_income <- data_last_ticks %>% 
    #group_by(i) %>%
    group_by(income.group) %>%
    summarise("num_evaders" = sum(tax.decision), "num_total" = n(), "evasion_share" = (sum(tax.decision)/n()))
  
  evasionshare_by_homophily <- data_last_ticks %>% 
    #group_by(i) %>%
    group_by(data.homophilystrength.tick.) %>%
    summarise("num_evaders" = sum(tax.decision), "num_total" = n(), "evasion_share" = (sum(tax.decision)/n()))
  
  evasion_highincome <- subset(data_last_ticks, income.group > 3)
  
  
  #evasion_highincome <- evasion_highincome %>% group_by(i, income.group) %>%
  #  summarise("homophilystrength" = data.homophilystrength.tick.,
  #            #"income_group" = income.group,
  #            "num_evaders" = sum(tax.decision),
  #            "num_total" = n(),
  #            "evasion_share" = (sum(tax.decision)/n()))
  
}

# Plots
{
  # Convergence Tests
  {
    # Plot Macro Tests
    {
      # P-Values
      {
        colnames(aDF_macro) <- c("Homophilystrength",
                                 "augmented Dickey-Fuller Parameter",
                                 "P-value")
        
        plotdata_aDF <- as.matrix(aDF_macro)
        plotdata_aDF <- as.data.frame(plotdata_aDF)
        
        plot_adfmacro_pvalues <- ggplot(plotdata_aDF, aes(x = plotdata_aDF[,3], y = stat(count/sum(count)))) +
          geom_histogram(color = "#f4bb44", fill = "#f4bb44", alpha = 0.5, bins = 10) +
          xlim(0,0.1) +
          xlab("P-values") +
          ylab("Frequency") + 
          theme_bw()
      }
      
      # Parameter Values
      {
        plot_adfmacro_parameter <- ggplot(plotdata_aDF_macro, aes(x = plotdata_aDF_macro[,2], y = stat(count/sum(count)))) +
          geom_histogram(color = "#f4bb44", fill = "#f4bb44", alpha = 0.5, bins = 10) +
          xlim(-25, 0) +
          xlab("Paramater values") +
          ylab("Frequency") + 
          theme_bw()
      }

    }
    
    # Plot Micro Tests
    {
      # P-values
      {
        colnames(aDF_micro) <- c("Homophilystrength",
                                 "augmented Dickey-Fuller Parameter",
                                 "P-value")
        
        plotdata_aDF <- as.matrix(aDF_micro)
        plotdata_aDF <- as.data.frame(plotdata_aDF)
        
        plot_adfmicro_pvalues <- ggplot(plotdata_aDF, aes(x = plotdata_aDF[,3], y = stat(count/sum(count)))) +
          geom_histogram(color = "#4586d6", fill = "#4586d6", alpha = 0.5, bins = 10) +
          xlim(0,0.1) +
          xlab("P-values") +
          ylab("Frequency") + 
          theme_bw()
      }
      
      # Parameter Values
      {
        
        plot_adfmicro_parameter <- ggplot(plotdata_aDF, aes(x = plotdata_aDF[,2], y = stat(count/sum(count)))) +
          geom_histogram(color = "#4586d6", fill = "#4586d6", alpha = 0.5, bins = 10) +
          xlim(-25, 0) +
          xlab("Parameter values") +
          ylab("Frequency") + 
          theme_bw()
      }
      
    }
      
  }
  
  # Convergence Tick
  {
    plot_conv_hs <- ggplot(conv_threshold, aes(x = as.factor(X0.25), y = X14)) +
      ggtitle("Time period of convergence with threshold = 0.1") +
      geom_violin(color = "#a6b1f7", fill = "#a6b1f7", alpha = 0.65) +
      geom_boxplot(width = 0.25, color = "black", alpha = 0.2) +
      xlab("Homophilystrength") + 
      ylab("Time period") +
      #scale_fill_viridis_b() +
      theme_bw()
  }
  
  # Evasion by income group
  {
    colnames(data_last_ticks) <- c("homophilystrength", "run", "income.group", "tax.decision")
    
    es_highincome <- subset(data_last_ticks, income.group > 3) %>%
      group_by(run, income.group) %>% summarise(homophilystrength = mean(homophilystrength),
                                              evader = sum(tax.decision),
                                              share = sum(tax.decision)/n())
    plot_es_income <- ggplot(es_highincome, aes(x = as.factor(homophilystrength), y = share, fill = as.factor(income.group))) +
      geom_violin(width = 1) +
      ggtitle("Evasion share for higher income groups by homophilystrength") +
      theme_bw() +
      scale_fill_manual(values = c("#faddc9", "#e97451")) +
      scale_color_manual(values = c("#faddc9", "#e97451")) +
      xlab("Homophilystrength") +
      ylab("Evasion share") +
      labs(fill = "Income group")
  }
}
