setwd("app/data/")

Sys.setenv(TZ="UTC")

library("quantmod")
library("financeR")
library("tseries")

data = read.csv("multisetsInputs.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, fileEncoding = "UTF-8")
data = data[-c(1, 30:41)]
crosses = toupper(gsub("\\.{3}[\\w]+|QUANDL\\.|\\.Price", "", names(data), perl = TRUE))
names(data) = crosses

tmp = matrix(nrow=nrow(data), ncol=ncol(data))
colnames(tmp) = colnames(data)

for(n in 1:ncol(data)){
	tmp[,n] = round(ROC(data[,n], 1, type = "discrete"), 6)
}

result = portfolio.optim(na.spline(tmp), shorts = TRUE)
pf = round(result$pw, 6)
names(pf) = names(data)
pf = sort(pf, decreasing = TRUE)

#barplot(pf, cex.names = 0.34)
out = as.data.frame(pf)
out = data.frame(cross = names(pf), percentage = pf)
write.csv(out, quote = FALSE, row.names = FALSE, file = "portfolio.csv", fileEncoding = "UTF-8")

quit()