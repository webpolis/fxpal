pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""));
dataPath = paste(pwd,"/../app/data/",sep="");

opts = commandArgs(trailingOnly = TRUE);
startDate = ifelse((length(opts)>0 && !is.na(opts[1])), opts[1], NA);
instrument = sub("(\\w{3})(\\w{3})", "\\1_\\2", ifelse((length(opts)>0 && !is.na(opts[2])), opts[2], "EURUSD"));
granularity = ifelse((length(opts)>0 && !is.na(opts[3])), opts[3], "H1");
type = ifelse((length(opts)>0 && !is.na(opts[4])), opts[4], NA);

oandaCurrencies = read.table(paste(dataPath,"oandaCurrencies.csv",sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8");
crosses = read.csv(paste(dataPath,"availableCrosses.csv",sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8");
crosses = as.character(crosses$instrument);

qfxAnalysis <- function(args){
	args = fromJSON(args);
	cross = instrument;

	out = getCandles(args$instrument, args$granularity, args$startDate);
	out = OHLC(out);

	trend = TrendDetectionChannel(out, n = 20, DCSector = .25);
	trend$Time = 0;
	trend$Time = index(out);

	patterns = getCandlestickPatterns(out);
	patterns$Time = 0;
	patterns$Time = out$Time;

	graphBreakoutArea(instrument,granularity,candles=out);

	write.csv(cbind(out,trend,patterns), quote = FALSE, row.names = FALSE, file = paste(dataPath,"candles/", cross, "-", granularity, ".csv", sep = ""), fileEncoding = "UTF-8");
}
qfxVolatility <- function(){
	vol = getVolatility(crosses);
	vol = vol[,vol>=0.011];
	tmp = matrix(as.list(vol));
	tmp = cbind(names(vol),tmp);
	colnames(tmp) = c("cross","volatility");
	vol = as.data.frame(tmp);
	vol = vol[with(vol, order(-(as.numeric(volatility)), cross)), ];

	write.csv(as.matrix(vol), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,"volatility.csv",sep=""), fileEncoding = "UTF-8");
}
qfxForce <- function(){
	table = round(getCrossesStrengthPerPeriod(crosses),6);
	table$period = rownames(table);
	strengths = getCurrencyStrengthPerPeriod(table[-(grep("period",colnames(table)))]);
	strengths$period = rownames(strengths);
	;
	write.csv(as.matrix(strengths), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,"force.csv",sep=""), fileEncoding = "UTF-8");
	write.csv(as.matrix(table), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,"forceCrosses.csv",sep=""), fileEncoding = "UTF-8");
}
qfxBreakout <- function(){
	graphBreakoutArea(instrument,granularity);
}