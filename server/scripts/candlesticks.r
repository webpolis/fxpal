setwd("app/data/")

library("RCurl")
library("rjson")
library("candlesticks")

opts = commandArgs(trailingOnly = TRUE)
oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786'
startDate = ifelse((exists("opts") && !is.na(opts[1])), opts[1], "2014-07-24")
instrument = sub("(\\w{3})(\\w{3})", "\\1_\\2", ifelse((exists("opts") && !is.na(opts[2])), opts[2], "USDCAD"))
granularity = ifelse((exists("opts") && !is.na(opts[3])), opts[3], "M")
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
#out = cbind(out, Cross = sub("_", "", instrument))
#out = cbind(out, Time = rownames(out))
out = as.xts(out)

trend = TrendDetectionChannel(out)

write.csv(trend, quote = FALSE, file = paste(instrument, "-trend-", granularity, ".csv", sep = ""), fileEncoding = "UTF-8")

quit()