setwd("app/data/")

Sys.setenv(TZ="UTC")

library("xts")
library("fPortfolio")
#library("financeR")
library("quantmod")

data = read.table("multisetsInputs.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = data[-grep("date", names(data), ignore.case=T)]
crosses = toupper(gsub("\\.{3}[\\w]+|CURRFX\\.|\\.\\d+|\\.Price", "", names(data), perl = TRUE))
names(data) = crosses

tmp = as.timeSeries(na.omit(data))
returns = returnSeries(tmp)

spec = portfolioSpec()
setNFrontierPoints(spec) <- 10
constraints <- c("Short")
setSolver(spec) <- "solveRshortExact"
setTargetReturn(spec) <- mean(returns)

mp = maxreturnPortfolio(tmp, spec, constraints)
ep = efficientPortfolio(tmp, spec, constraints)
mpWeights = getWeights(mp)
epWeights = getWeights(ep)

mediumWeights = round((mpWeights + epWeights) / 2, 6)
names(mediumWeights) = names(tmp)
mediumWeights = sort(mediumWeights, decreasing = TRUE)

# result = portfolio.optim(na.spline(tmp), shorts = TRUE)
# pf = round(result$pw, 6)
# names(pf) = names(data)
# pf = sort(pf, decreasing = TRUE)

#barplot(pf, cex.names = 0.34)

out = data.frame(cross = names(mediumWeights), percentage = mediumWeights)
out = out[out$percentage>0.025|out$percentage< -0.025,]
write.csv(out, quote = FALSE, row.names = FALSE, file = "portfolio.csv", fileEncoding = "UTF-8")

quit()
