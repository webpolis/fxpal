setwd("../")
source("server/scripts/header.r")
sink(type="message")
library(CVMatcher)
USDJPY=getLiveCandles("USD_JPY","D")
#write.csv(USDJPY, quote = FALSE, row.names = FALSE, file = "cv/USDJPY.csv", fileEncoding = 'UTF-8')
CVMatcher::process(OHLC(USDJPY),OHLC(USDJPY),8)
