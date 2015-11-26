pwd = ifelse(is.null(sys.frames()),paste(getwd(),"/server/scripts",sep=""),dirname(sys.frame(1)$ofile))
dataPath = paste(pwd,"/../../app/data/",sep="")

Sys.setenv(TZ="UTC")

library("xts")
library("fPortfolio")
library("quantmod")
library("financeR")

#stocks = c("AMZN", "DOX", "AXP", "BRK-A", "TSLA", "TEVA", "PG", "AAPL", "CSCO", "CAT", "XOM", "GM", "GOOG", "INTC", "JNJ", "PFE", "BP", "SAP", "GSK", "SIE.DE", "VZ", "GS")
stocks = c("ADBE","ADSK","ALU.PA","AMX","ARM.L","ATVI","BIDU","CAP.PA","CHKP","CHL","CSCO","DMGT.L","DTE.DE","EA","FB","FSLR","GOOG","HPQ","IBM","IFX.DE","INTC","KING","LNKD","MSFT","MSI","MU","NOK","NVDA","ORCL","RENN","SAP.DE","SGE.L","SNDK", "TEF","TEO","TRIP","TWTR","VOD","VOD.L","VZ","WDC","YHOO","YNDX","ZNGA")

#merval
#stocks = read.table(paste0(dataPath, "merval.csv"), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")$symbol
#stocks = as.character(lapply(stocks,FUN=function(x){paste(x,"BA",sep=".")}))

tickers = getSymbols(stocks, auto.assign = TRUE)

dataset <- Ad(get(tickers[1]))
for (i in 2:length(tickers)) {
	dataset <- merge(dataset, Ad(get(tickers[i])))
}

return_lag <- 5
data <- na.omit(ROC(na.spline(dataset), return_lag, type = "discrete"))
scenarios <- dim(data)[1]
assets <- dim(data)[2]
names(data) <- stocks

tmp = as.timeSeries(data)
spec = portfolioSpec()
setNFrontierPoints(spec) <- 10
constraints <- c("LongOnly")
setSolver(spec) <- "solveRquadprog"
setTargetReturn(spec) <- mean(colMeans(tmp))

# portfolioConstraints(data, spec, constraints)
# frontier <- portfolioFrontier(data, spec, constraints)
# print(frontier)
# tailoredFrontierPlot(object = frontier)

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
out=out[out$percentage>0,]

#barplot(height = out$percentage,names.arg = out$cross,cex.names = 0.5)

outFile = "stocksPortfolio"

write.csv(out, quote = FALSE, row.names = FALSE, file = paste(dataPath, paste(outFile,'.csv',sep=''),sep=""), fileEncoding = "UTF-8")
