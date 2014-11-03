pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""));
dataPath = paste(pwd,"/../app/data/",sep="");

data = read.table(paste(dataPath,"multisetsInputs.csv",sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8");
data = data[-c(1, 30:41)];
crosses = toupper(gsub("\\.{3}[\\w]+|QUANDL\\.|\\.Price", "", names(data), perl = TRUE));
names(data) = crosses;

tmp = matrix(nrow=nrow(data), ncol=ncol(data));
colnames(tmp) = colnames(data);

for(n in 1:ncol(tmp)){
	tmp[,n] = round(ROC(data[,n], 1, type = "discrete"), 6);
}

returns = na.spline(tmp);
returns = as.timeSeries(returns);
spec = portfolioSpec();
setNFrontierPoints(spec) = 10;
constraints = c("Short");
setSolver(spec) = "solveRshortExact";
setTargetReturn(spec) = mean(colMeans(returns));

tp = tangencyPortfolio(returns, spec, constraints);
mp = maxreturnPortfolio(returns, spec, constraints);
ep = efficientPortfolio(returns, spec, constraints);
tpWeights = getWeights(tp);
mpWeights = getWeights(mp);
epWeights = getWeights(ep);

mediumWeights = round((tpWeights + mpWeights + epWeights) / 3, 6);
names(mediumWeights) = names(returns);
mediumWeights = sort(mediumWeights, decreasing = TRUE);

out = as.data.frame(mediumWeights);
out = data.frame(cross = names(mediumWeights), percentage = mediumWeights);
write.csv(out, quote = FALSE, row.names = FALSE, file = paste(dataPath,"portfolio.csv",sep=""), fileEncoding = "UTF-8");
