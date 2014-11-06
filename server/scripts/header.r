library(candlesticks)
library(grid)
library(png)
library(TTR)
library(xts)
#library(fPortfolio)
library(quantmod)
library(PerformanceAnalytics)
library(rjson)
library(RCurl)

Sys.setenv(TZ='UTC')

pwd = getwd()
dataPath = paste(pwd,'/app/data/',sep='')
logFile = file(paste(dataPath,'R.log',sep=''),open='wt')
sink(logFile,type='message')

getCandles <- function(instrument, granularity, startDate = NA, count = 600){
	inFile = paste(dataPath,'candles/', instrument, '-', granularity, '.json', sep = '')
	json = fromJSON(readChar(inFile,nchars=1e6))
	print("done importing json candles")

	ret = NULL
	for(c in 1:length(json$candles)){
		candle = as.data.frame(json$candles[c])
		rbind(ret, candle) -> ret
	}

	ret = ret[,-(grep('[a-z]+Ask|complete',names(ret)))]
	rownames(ret) = ret[,1]
	ret = ret[,-1]

	colnames(ret) = c('Open','High','Low','Close','Volume')
	rownames(ret) = as.POSIXlt(gsub('T|\\.\\d{6}Z', ' ', rownames(ret)))
	ret = as.xts(ret)

	return(ret)
}

getCandlestickPatterns <- function(ohlc){
	ret = xts()
	cMethods = ls('package:candlesticks')
	csp = cMethods[grep('^CSP.*', cMethods)]
	csp = csp[-(grep('CSP(?:Long|Short)Candle(?:Body)?', csp, ignore.case = TRUE, perl = TRUE))]
	for(c in 1:length(csp)){
		tryCatch({
			method = paste(csp[c], '(ohlc)', sep = '')
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
		tmp = getCandles(cross,'H1',count = 8)
		vol = volatility(tmp, n=6,calc='garman.klass')
		names(vol) = c(cross)
		ret = cbind(vol,ret)
	}
	ret = na.omit(ret)
	return(ret[nrow(ret),])
}

getSlopeByPeriod <- function(currency, period){
	newPeriod = period
	newCount = 0
	switch(period,M15={
		newPeriod = 'M1'
		newCount = 15
	},H1={
		newPeriod = 'M5'
		newCount = 12
	},D={
		newPeriod = 'H2'
		newCount = 12
	},W={
		newPeriod = 'D'
		newCount = 7
	},M={
		newPeriod = 'D'
		newCount = 30
	})
	print(paste("getSlopeByPeriod",currency,newPeriod,newCount,sep='-'))
	tmp = getCandles(currency,newPeriod,count = newCount)
	roc = na.omit(ROC(Cl(tmp),type='discrete'))
	lm = lm(roc~na.omit(ROC(tmp$Volume,type='discrete')))
	f = as.numeric(fitted(lm))

	return(last(atan(f)))
}

getCrossesStrengthPerPeriod <- function(crosses){
	periods = c('M15','H1','D','W','M')
	df = data.frame(matrix(ncol=length(crosses),nrow=length(periods)))

	rownames(df) = periods
	colnames(df) = crosses

	for(cross in crosses){
		for(period in periods){
			tmp = getSlopeByPeriod(cross,period)
			df[period,cross] = tmp
		}
	}

	return(df)
}

# argument must be return of getCrossesStrengthPerPeriod
getCurrencyStrengthPerPeriod <- function(table){
	periods = rownames(table)
	crosses = colnames(table)
	cross1 = sub('(\\w{3})_(\\w{3})','\\1',crosses)
	cross2 = sub('(\\w{3})_(\\w{3})','\\2',crosses)
	currencies = unique(c(cross1,cross2))

	df = data.frame(matrix(ncol=length(currencies),nrow=length(periods)))
	rownames(df) = periods
	colnames(df) = sort(currencies)
	df[is.na(df)] = 0

	for(cross in crosses){
		cross1 = sub('(\\w{3})_(\\w{3})','\\1',cross)
		cross2 = sub('(\\w{3})_(\\w{3})','\\2',cross)

		for(period in periods){
			val = table[period,cross]

			if(val>0){
				df[period,cross1] = df[period,cross1] + val
				df[period,cross2] = df[period,cross2] - val
			}else if(val<0){
				df[period,cross1] = df[period,cross1] - val
				df[period,cross2] = df[period,cross2] + val
			}
		}
	}

	return(df)
}

getSupportsAndResistances <- function(candles){
	prices = HLC(candles)
	dc = lag(DonchianChannel(Cl(prices),n=20),-2)
	dc$count = 1

	t = table(dc$high)
	t2 = table(dc$low)
	resistances = as.double(names(t[t>10]))
	supports = as.double(names(t2[t2>10]))
	resdist = as.matrix(dist(resistances,method='manhattan'))
	colnames(resdist) = resistances
	rownames(resdist) = resistances
	supdist = as.matrix(dist(supports,method='manhattan'))
	colnames(supdist) = supports
	rownames(supdist) = supports

	resLessDistances = sort(resdist[resdist<sd(resdist)&resdist>0])
	supLessDistances = sort(supdist[supdist<sd(supdist)&supdist>0])
	resMinDistance = max(resLessDistances[1:ceiling(10*length(resLessDistances)/100)])
	resMinDistance = ifelse(resMinDistance<0.0005,max(resLessDistances),resMinDistance)
	supMinDistance = max(supLessDistances[1:ceiling(10*length(supLessDistances)/100)])
	supMinDistance = ifelse(supMinDistance<0.0005,max(supLessDistances),supMinDistance)

	resmerge = which(resdist<0.0005&resdist>0,arr.ind=T)
	supmerge = which(supdist<0.0005&supdist>0,arr.ind=T)

	resavg = unique(sapply(rownames(resmerge),FUN=function(rn){price = mean(c(as.double(rn),as.double(colnames(resdist)[resmerge[rn,'col']])))}))
	supavg = unique(sapply(rownames(supmerge),FUN=function(sn){price = mean(c(as.double(sn),as.double(colnames(supdist)[supmerge[sn,'col']])))}))

	resdif = setdiff(resistances,as.double(rownames(resmerge)))
	supdif = setdiff(supports,as.double(rownames(supmerge)))

	if(length(resavg)==0){
		resistances = sort(resdif)
	}else{
		resistances = sort(c(resavg,resdif))		
	}

	if(length(supavg)==0){
		supports = sort(supdif)
	}else{
		supports = sort(c(supavg,supdif))		
	}

	ret = list('resistances'=resistances,'supports'=supports)

	return(ret)
}

addCopyright <- function(label, image, x, y, size, ...) {
	lab = textGrob(label = label, x = unit(x, 'npc'), y = unit(y, 'npc'),just = c('left', 'centre'), gp = gpar(...))
	logo = rasterGrob(image = image,
	x = unit(x, 'npc') + unit(1, 'grobwidth', lab), y = unit(y, 'npc'),
	width = unit(size, 'cm'), height = unit(size, 'cm'),
	just = c('left', 'centre'), gp = gpar(...))
	grid.draw(lab)
	grid.draw(logo)
}

graphBreakoutArea <- function(instrument='EUR_USD',granularity='D',candles=NA,bars=600,save=T,showGraph=F,fillCongested=T,drawLines=F){
	if(is.na(candles)){
		candles = getCandles(instrument,granularity,count=bars)
	}
	prices = HLC(candles)
	ret = getSupportsAndResistances(candles)

	if(!is.null(ret$resistances)&!is.null(ret$supports)){
		if(showGraph){
			dev.new()
			lineChart(Cl(candles),name=paste(instrument,granularity,sep=' - '))
		}
		if(save){
			iname = paste(dataPath,'breakout/', instrument, '-', granularity, '.jpg', sep = '')
			print(paste('saving image',iname))
			jpeg(iname,width=1334,height=750,quality=100)
			lineChart(Cl(candles),name=paste(instrument,granularity,sep=' - '))
			print("done")
		}

		if(drawLines){
			for(r in ret$resistances){addLines(h=r,on=1,col='blue')}
			for(r in ret$supports){addLines(h=r,on=1,col='red')}
		}

		axis(2,at=round(c(ret$resistances,ret$supports),3),cex.axis=0.9,col.axis='white')

		# fill areas
		if(fillCongested){
			resdif = diff(ret$resistances)
			supdif = diff(ret$supports)

			lapply(seq_along(resdif),FUN=function(x){
				if(length(resdif) == 0) return
				sdDif = ifelse(length(resdif)==1,resdif[1],sd(resdif))

				if(resdif[x]>sdDif){
					fp=ret$resistances[x]
					lp=ret$resistances[x+1]
					rect(0,fp,length(index(prices)),lp,col=rgb(0.955,0.955,0.855,0.25),border='blue')
				}
			})
			lapply(seq_along(supdif),FUN=function(x){
				if(length(supdif) == 0) return
				sdDif = ifelse(length(supdif)==1,supdif[1],sd(supdif))

				if(supdif[x]>sdDif){
					fp=ret$supports[x]
					lp=ret$supports[x+1]
					rect(0,fp,length(index(prices)),lp,col=rgb(0.955,0.955,0.855,0.25),border='red')
				}
			})
		}

		# add copyright
		year = format(Sys.time(),'%Y')
		path = paste(dataPath,'../images/logo-s.png',sep='')
		logo = readPNG(path)
		addCopyright(paste('Powered by ',sep=''),logo,x = unit(0.5, 'npc'), y = unit(0.942, 'npc'),1,fontsize=10, col='white')

		if(save){
			dev.off()
		}
	}
}

getPosition <- function(currency){
	curr = subset(data,Market.and.Exchange.Names==currency)
	cl = ROC(rev(curr$Noncommercial.Positions.Long..All.),type='discrete')
	cs = ROC(rev(curr$Noncommercial.Positions.Short..All.),type='discrete')
	ci = ROC(rev(curr$Open.Interest..All.),type='discrete')
	pos = matrix(c(cl,cs,ci),ncol=3,dimnames=list(NULL,c('long','short','interest')))
	ret = last(zoo(pos))
	index(ret) = c(currency)
	return(ret)
}

qfxAnalysis <- function(args){
	print(paste('Running qfxAnalysis. Data path is',dataPath,sep=' '))
	args = fromJSON(args)
	outFile = paste(dataPath,'candles/', args$instrument, '-', args$granularity, '.csv', sep = '')

	out = getCandles(args$instrument, args$granularity, args$startDate)
	out = OHLC(out)

	trend = TrendDetectionChannel(out, n = 20, DCSector = .25)
	trend$Time = 0
	trend$Time = index(out)
	out = cbind(out,trend)

	#patterns = getCandlestickPatterns(out)
	#patterns$Time = 0
	#patterns$Time = out$Time
	#out = cbind(out,patterns)

	# Rserve ignores call to jpeg. Move this to custom script
	#graphBreakoutArea(args$instrument,args$granularity,candles=OHLC(out))
	print(paste("saving to",outFile))
	write.csv(out, quote = FALSE, row.names = FALSE, file = outFile, fileEncoding = 'UTF-8')
}
qfxVolatility <- function(){
	print(paste('Running qfxVolatility. Data path is',dataPath,sep=' '))
	vol = getVolatility(crosses)
	vol = vol[,vol>=0.011]
	tmp = matrix(as.list(vol))
	tmp = cbind(names(vol),tmp)
	colnames(tmp) = c('cross','value')
	vol = as.data.frame(tmp);	
	vol = vol[with(vol, order(-(as.numeric(value)), cross)), ]

	write.csv(as.matrix(vol), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,'volatility.csv',sep=''), fileEncoding = 'UTF-8')
}
qfxForce <- function(){
	print(paste('Running qfxForce. Data path is',dataPath,sep=' '))
	table = round(getCrossesStrengthPerPeriod(crosses),6)
	table$period = rownames(table)
	strengths = getCurrencyStrengthPerPeriod(table[-(grep('period',colnames(table)))])
	strengths$period = rownames(strengths)

	write.csv(as.matrix(strengths), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,'force.csv',sep=''), fileEncoding = 'UTF-8')
	write.csv(as.matrix(table), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,'forceCrosses.csv',sep=''), fileEncoding = 'UTF-8')
}
qfxBreakout <- function(args){
	print(paste('Running qfxBreakout. Data path is',dataPath,sep=' '))
	args = fromJSON(args)
	graphBreakoutArea(args$instrument, args$granularity)
}