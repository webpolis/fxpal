crosses = read.csv(paste(dataPath,'availableCrosses.csv',sep=''), sep = ',', dec = '.', strip.white = TRUE, header=TRUE, encoding = 'UTF-8')
crosses = as.character(crosses$instrument)