setwd("app/data/")

library("RCurl")
library("rjson")
library("candlesticks")

oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786'
urlPractice = "https://api-fxpractice.oanda.com/v1/candles?instrument=USD_CAD&granularity=H1&start=2014-07-24&weeklyAlignment=Monday"

ret = fromJSON(getURL(url = urlPractice, httpheader = c(Authorization = paste("Bearer ", oandaToken))))

out = NULL
for(c in 1:length(ret$candles)){
	candle = as.data.frame(ret$candles[c])
	rbind(out, candle) -> out
}

quit()