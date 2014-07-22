setwd("app/data/")
data <- read.csv("eventsCrossesInputs.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, fileEncoding = "UTF-8")

correlation <- cor(as.matrix(data), use = "everything")
##write.csv(correlation, quote = FALSE, file = "tmp.csv", fileEncoding = "UTF-8")

library(MASS)
write.matrix(correlation, file = "tmp.csv", sep = ",")
quit()