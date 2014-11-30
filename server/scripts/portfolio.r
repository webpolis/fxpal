setwd("app/data/")

Sys.setenv(TZ="UTC")

library("xts")
library("fPortfolio")
#library("financeR")
library("quantmod")

data = read.table("multisetsInputs.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = data[-c(1, 30:41)]
crosses = toupper(gsub("\\.{3}[\\w]+|CURRFX\\.|\\.Price", "", names(data), perl = TRUE))
names(data) = crosses

tmp = matrix(nrow=nrow(data), ncol=ncol(data))
colnames(tmp) = colnames(data)

for(n in 1:ncol(data)){
	tmp[,n] = round(ROC(data[,n], 1, type = "discrete"), 6)
}

tmp = as.timeSeries(na.spline(tmp))
spec = portfolioSpec()
setNFrontierPoints(spec) <- 10
constraints <- c("Short")
setSolver(spec) <- "solveRshortExact"
setTargetReturn(spec) <- mean(colMeans(tmp))

tp = tangencyPortfolio(tmp, spec, constraints)
mp = maxreturnPortfolio(tmp, spec, constraints)
ep = efficientPortfolio(tmp, spec, constraints)
tpWeights = getWeights(tp)
mpWeights = getWeights(mp)
epWeights = getWeights(ep)

mediumWeights = round((tpWeights + mpWeights + epWeights) / 3, 6)
names(mediumWeights) = names(tmp)
mediumWeights = sort(mediumWeights, decreasing = TRUE)

# result = portfolio.optim(na.spline(tmp), shorts = TRUE)
# pf = round(result$pw, 6)
# names(pf) = names(data)
# pf = sort(pf, decreasing = TRUE)

#barplot(pf, cex.names = 0.34)

out = data.frame(cross = names(mediumWeights), percentage = mediumWeights)
out = out[out$percentage>0.006|out$percentage< -0.005,]
write.csv(out, quote = FALSE, row.names = FALSE, file = "portfolio.csv", fileEncoding = "UTF-8")

quit()
