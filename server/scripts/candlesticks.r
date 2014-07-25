setwd("app/data/")

Sys.setenv(TZ="UTC")

library("RCurl")
library("rjson")
library("candlesticks")

opts = commandArgs(trailingOnly = TRUE)
startDate = ifelse((exists("opts") && !is.na(opts[1])), opts[1], "2014-07-24")
instrument = sub("(\\w{3})(\\w{3})", "\\1_\\2", ifelse((exists("opts") && !is.na(opts[2])), opts[2], "USDCAD"))
granularity = ifelse((exists("opts") && !is.na(opts[3])), opts[3], "M")
type = ifelse((exists("opts") && !is.na(opts[4])), opts[4], "trend")

getCandles <- function(instrument, granularity, startDate){
	oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786'
	urlPractice = paste("https://api-fxpractice.oanda.com/v1/candles?instrument=", instrument, "&granularity=", granularity, "&start=", startDate, "&weeklyAlignment=Monday", sep = "")

	print(urlPractice)

	ret = fromJSON(getURL(url = urlPractice, httpheader = c(Authorization = paste("Bearer ", oandaToken))))

	out = NULL
	for(c in 1:length(ret$candles)){
		candle = as.data.frame(ret$candles[c])
		rbind(out, candle) -> out
	}

	out = out[,-(grep("[a-z]+Bid|complete",names(out)))]
	rownames(out) = out[,1]
	out = out[,-1]
	names(out) = c("Open","High","Low","Close","Volume")
	rownames(out) = as.POSIXlt(gsub("T|\\.\\d{6}Z", " ", rownames(out)))
	out = as.xts(out)
	return(out)
}

out = getCandles(instrument, granularity, startDate)

if(type == "trend"){
	trend = TrendDetectionChannel(out)
	trend$Time = 0
	trend$Time = index(out)

	write.csv(trend, quote = FALSE, row.names = FALSE, file = paste(instrument, "-trend-", granularity, ".csv", sep = ""), fileEncoding = "UTF-8")
}
# match candlesticks patterns
if(granularity == "D"){

}

quit()