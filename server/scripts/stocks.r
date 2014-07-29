setwd("app/data/")

Sys.setenv(TZ="UTC")

library("xts")
library("fPortfolio")
library("quantmod")

stocks = c("AMZN", "DOX", "AXP", "BRK-A", "TSLA", "TEVA", "PG", "AAPL", "CSCO", "CAT", "XOM", "GM", "GOOG", "INTC", "JNJ", "PFE", "BP", "SAP", "GSK", "SIE.DE", "VZ", "GS")

tickers = getSymbols(stocks, auto.assign = TRUE)

dataset <- Ad(get(tickers[1]))
for (i in 2:length(tickers)) {
	dataset <- merge(dataset, Ad(get(tickers[i])))
}

return_lag <- 5  # (crude) weekly returns
data <- na.omit(ROC(na.spline(dataset), return_lag, type = "discrete"))
names(data) <- stocks

tmp = as.timeSeries(data)
spec = portfolioSpec()
setNFrontierPoints(spec) <- 10
constraints <- c("LongOnly")
setSolver(spec) <- "solveRquadprog"
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

out = as.data.frame(mediumWeights)
out = data.frame(cross = names(mediumWeights), percentage = mediumWeights)

write.csv(out, quote = FALSE, row.names = FALSE, file = "stocksPortfolio.csv", fileEncoding = "UTF-8")

quit()