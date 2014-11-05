setwd('app/data/')

Sys.setenv(TZ='UTC')

data = read.csv('eventsCrossesInputs.csv', sep = ',', dec = '.', strip.white = TRUE, header=TRUE, encoding = 'UTF-8')
names(data) = toupper(gsub('\\.{3}[\\w]+|QUANDL\\.|\\.Price', '', names(data), perl = TRUE))

data = cor(data, use='pairwise.complete.obs', method='pearson')
correlation = as.data.frame(as.table(data))
correlation = na.omit(correlation)
names(correlation) = c('cross1', 'cross2', 'rel')
correlation = correlation[correlation$rel!=1,]

write.csv(correlation, quote = FALSE, row.names = FALSE, file = 'eventsCrossesOutputs.csv', fileEncoding = 'UTF-8')

quit()