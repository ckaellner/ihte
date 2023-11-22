# Source: https://www.einkommensverteilung.eu/deutschland/

# Income data under 0 will be dropped for simplicity (the code worked with the income data under 0 as well).
# Legacy data for the income distribution frequency with < 0 incomes included:
# distribution <- c(1.98, 8.77, 9.95, 11.17, 10.29, 9.56, 8.98, 8.17, 6.62, 5.07, 3.9, 5.17, 3.01, 1.9, 1.27, 0.87, 1.24, 1.56, 0.38, 0.1, 0.04)
#
# Calculation of new frequencies with the help of adjusting the relative frequency base from 100 to 100 - 1.98 = 98.02

# Install packages
{
  if (!require("ggplot2")) install.packages("ggplot2")
  if (!require("hrbrthemes")) install.packages("hrbrthemes")
  
  library(ggplot2)
  library(hrbrthemes)
}

# Key Data of the distribution provided by Angerer
{
  distribution <- c(8.77, 9.95, 11.17, 10.29, 9.56, 8.98, 8.17, 6.62, 5.07, 3.9, 5.17, 3.01, 1.9, 1.27, 0.87, 1.24, 1.56, 0.38, 0.1, 0.04)
  relative_frequencies <- distribution/98.02
  population <- relative_frequencies * 1000000
}

# Income intervall labels & edges
{
  income_intervalls <- c("0-5.000",
                         "5.000-10.000", 
                          "10.000-15.000",
                          "15.000-20.000",
                          "20.000-25.000",
                          "25.000-30.000",
                          "30.000-35.000",
                          "35.000-40.000",
                          "40.000-45.000",
                          "45.000-50.000",
                          "50.000-60.000",
                          "60.000-70.000",
                          "70.000-80.000",
                          "80.000-90.000",
                          "90.000-100.000",
                          "100.000-125.000",
                          "125.000-250.000",
                          "250.000-500.000",
                          "500.000-1.000.000",
                          ">1.000.000")

  income_edges <- c(0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 
                    40000, 45000, 50000, 60000, 70000, 80000, 90000, 100000,
                    125000, 250000, 500000, 1000000, 2000000)
}

# Drawing of income data
{
  income_data <- c()

  num_income_groups <- length(income_intervalls)

  for (i in 1:num_income_groups){
    income_data <- c(income_data, round(runif(population[i], min = income_edges[i], max = income_edges[i + 1])))
  }
}

# Storing of income data into .csv-file
{
  write.csv2(income_data, "sim_income_data_germany.csv", row.names = FALSE)
}

# Plot generation
{
  income_data <- as.data.frame(income_data)
  
  ggplot(data = income_data, aes(x = income_data)) + 
    geom_histogram(binwidth = 10) + 
    geom_density(color = "blue", size = 2) +
    #theme_ipsum() + 
    xlim(0,150000)
  
  density_line <- smooth.spline(income_data)
  
  ggplot(data = income_data, aes(x = income_data)) + 
    ggtitle("Distribution of German pre-tax income in 2020") +
    geom_histogram(aes(y = ..density..), colour = "#8A9A5B", fill = "#8A9A5B", alpha = 0.5, bins = 40) +
    scale_y_continuous(labels = scales::percent) +
    #geom_density(aes(x = income_data), color = "black", alpha = .25) + 
    geom_density(adjust = 2.25, colour = "#8A9A5B", alpha = 0, size = 0.75) +
    xlab("Annual pre-tax income") +
    ylab("Frequency") +
    theme_bw() +
    xlim(0,125000)
                             
}



