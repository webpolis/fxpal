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

	json = fromJSON(getURL(url = urlPractice, httpheader = c(Authorization = paste("Bearer ", oandaToken))))

	ret = NULL
	for(c in 1:length(json$candles)){
		candle = as.data.frame(json$candles[c])
		rbind(ret, candle) -> ret
	}

	ret = ret[,-(grep("[a-z]+Bid|complete",names(ret)))]
	rownames(ret) = ret[,1]
	ret = ret[,-1]
	names(ret) = c("Open","High","Low","Close","Volume")
	rownames(ret) = as.POSIXlt(gsub("T|\\.\\d{6}Z", " ", rownames(ret)))
	ret = as.xts(ret)
	return(ret)
}

getCandlestickPatterns <- function(varName){
	ret = xts()
	cMethods = ls(package:candlesticks)
	csp = cMethods[grep("^CSP.*", cMethods)]
	for(c in 1:length(csp)){
		tryCatch({
			tmp = eval(parse(text = paste(csp[c], "(", varName, ")", sep = "")))
			ret = merge(tmp, ret)
		}, error = function(cond){
			return(NA)
		})
	}
	return(ret)
}

out = getCandles(instrument, granularity, startDate)

if(type == "trend"){
	trend = TrendDetectionChannel(out)
	trend$Time = 0
	trend$Time = index(out)

	write.csv(trend, quote = FALSE, row.names = FALSE, file = paste(instrument, "-trend-", granularity, ".csv", sep = ""), fileEncoding = "UTF-8")
}
# match candlesticks patterns
if(granularity == "D" && type == "patterns"){
	if(exists("out")){
		patterns = getCandlestickPatterns()
		patterns$Time = 0
		patterns$Time = index(out)
		write.csv(patterns, quote = FALSE, row.names = FALSE, file = paste(instrument, "-patterns-", granularity, ".csv", sep = ""), fileEncoding = "UTF-8")
	}
}

quit()