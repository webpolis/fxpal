pwd = ifelse(is.null(sys.frames()),paste(getwd(),"/server/scripts",sep=""),dirname(sys.frame(1)$ofile))
dataPath = paste(pwd,"/../../app/data/",sep="")

Sys.setenv(TZ="UTC")

library("xts")
library("fPortfolio")
library("financeR")
library("quantmod")

forex = read.csv(paste(dataPath, 'availableCrosses.csv', sep=""), sep = ',', dec = '.', strip.white = TRUE, header=TRUE, encoding = 'UTF-8')
forex = gsub("_", "", as.character(forex$instrument))

dataset = read.table(paste(dataPath, "multisetsInputs.csv", sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
rownames(dataset) = dataset[grep("date", names(dataset), ignore.case=T)]$Date
dataset = dataset[-grep("date", names(dataset), ignore.case=T)]
crosses = toupper(gsub("\\.{3}[\\w]+|CURRFX\\.|\\.\\d+|\\.Price", "", names(dataset), perl = TRUE))
names(dataset) = crosses

dataset = dataset[,forex]

return_lag <- 5
data <- na.omit(ROC(na.spline(as.xts(dataset)), return_lag, type = "discrete"))
scenarios <- dim(data)[1]
assets <- dim(data)[2]

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

outFile = "forexPortfolio"

write.csv(out, quote = FALSE, row.names = FALSE, file = paste(dataPath, paste(outFile,'.csv',sep=''),sep=""), fileEncoding = "UTF-8")
