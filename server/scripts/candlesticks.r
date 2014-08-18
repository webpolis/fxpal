Sys.setenv(TZ="UTC")

pwd = ifelse(is.null(sys.frames()),getwd(),dirname(sys.frame(1)$ofile))
dataPath = paste(pwd,"/../../app/data/",sep="")

library("RCurl")
library("rjson")
library("candlesticks")

opts = commandArgs(trailingOnly = TRUE)
startDate = ifelse((length(opts)>0 && !is.na(opts[1])), opts[1], NA)
instrument = sub("(\\w{3})(\\w{3})", "\\1_\\2", ifelse((length(opts)>0 && !is.na(opts[2])), opts[2], "EURUSD"))
granularity = ifelse((length(opts)>0 && !is.na(opts[3])), opts[3], "H1")
type = ifelse((length(opts)>0 && !is.na(opts[4])), opts[4], "analysis")

oandaCurrencies = read.table(paste(dataPath,"oandaCurrencies.csv",sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
isReverted = nrow(oandaCurrencies[oandaCurrencies$instrument == instrument,]) <= 0
instrument = ifelse(isReverted,sub("([a-z]{3})_([a-z]{3})", "\\2_\\1",instrument,ignore.case=TRUE),instrument)

getCandles <- function(instrument, granularity, startDate = NA, count = 600){
	oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786'
	urlPractice = paste("https://api-fxpractice.oanda.com/v1/candles?instrument=", instrument, "&granularity=", granularity, "&weeklyAlignment=Monday", "&candleFormat=bidask", sep = "")

	if(!is.na(startDate)){
		urlPractice = paste(urlPractice,"&start=", startDate,sep="")
	}else if(!is.na(count)){
		urlPractice = paste(urlPractice,"&count=", count,sep="")
	}

	print(paste("requesting ",urlPractice))

	json = fromJSON(getURL(url = urlPractice, httpheader = c("Accept" = "application/json", "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:31.0) Gecko/20100101 Firefox/31.0", Authorization = paste("Bearer ", oandaToken))))

	ret = NULL
	for(c in 1:length(json$candles)){
		candle = as.data.frame(json$candles[c])
		rbind(ret, candle) -> ret
	}

	ret = ret[,-(grep("[a-z]+Ask|complete",names(ret)))]
	rownames(ret) = ret[,1]
	ret = ret[,-1]
	names(ret) = c("Open","High","Low","Close","Volume")
	rownames(ret) = as.POSIXlt(gsub("T|\\.\\d{6}Z", " ", rownames(ret)))
	ret = as.xts(ret)

	if(isReverted){
		ret[,1:4] = 1/ret[,1:4]
		l = ret$Low
		h = ret$High
		ret$High = l
		ret$Low = h
	}
	return(ret)
}

getCandlestickPatterns <- function(varName){
	ret = xts()
	cMethods = ls("package:candlesticks")
	csp = cMethods[grep("^CSP.*", cMethods)]
	csp = csp[-(grep('CSP(?:Long|Short)Candle(?:Body)?', csp, ignore.case = TRUE, perl = TRUE))]
	for(c in 1:length(csp)){
		tryCatch({
			method = paste(csp[c], "(", varName, ")", sep = "")
			tmp = eval(parse(text = method))
			ret = merge(tmp, ret)
		}, error = function(cond){
			return(NA)
		})
	}
	return(ret)
}

getVolatility <- function(crosses){
	ret = xts()
	for(cross in crosses){
		tmp = getCandles(cross,"H1",count = 8)
		vol = volatility(n=6,calc="garman.klass",OHLC(tmp))
		names(vol) = c(cross)
		ret = merge(vol,ret)
	}
	ret = na.omit(ret)
	return(ret[nrow(ret),])
}
if(type == "analysis"){
	cross = instrument

	if(isReverted){
		cross = ifelse(isReverted,sub("([a-z]{3})_([a-z]{3})", "\\2_\\1",cross,ignore.case=TRUE),cross)
	}
	out = getCandles(instrument, granularity, startDate)
	ohlc = OHLC(out)

	trend = TrendDetectionChannel(ohlc, n = 20, DCSector = .25)
	trend$Time = 0
	trend$Time = index(out)
	
	patterns = getCandlestickPatterns("ohlc")
	patterns$Time = 0
	patterns$Time = out$Time

	write.csv(cbind(out,trend,patterns), quote = FALSE, row.names = FALSE, file = paste(dataPath,"candles/", cross, "-", granularity, ".csv", sep = ""), fileEncoding = "UTF-8")
}
if(type == "volatility"){
	crosses = read.csv(paste(dataPath,"availableCrosses.csv",sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
	crosses = as.character(crosses$instrument)
	vol = getVolatility(crosses)
	vol = vol[,vol>=0.0081]
	tmp = matrix(as.list(vol))
	tmp = cbind(names(vol),tmp)
	colnames(tmp) = c("cross","volatility")
	vol = as.data.frame(tmp)

	write.csv(as.matrix(vol), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,"volatility.csv",sep=""), fileEncoding = "UTF-8")
}

if(length(opts)>0){
	quit()
}