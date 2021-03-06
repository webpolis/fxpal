library(candlesticks)
library(grid)
library(png)
library(TTR)
library(xts)
library(quantmod)
library(PerformanceAnalytics)
library(rjson)
library(RCurl)
library(DSTrading)
library(IKTrading)
library(quantstrat)
library(ggplot2)

Sys.setenv(TZ='UTC')
Sys.setlocale("LC_CTYPE","en_US.UTF-8")
options(scipen=999)

oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786'
#oandaToken = 'db20e99d133e919fbc5b7363e699774c-50bdf5f0e579d95c98cde13d56beed59'

maxWidth=1334
maxHeight=750

pwd = getwd()
dataPath = paste(pwd,'/app/data/',sep='')
tmpPath = paste(pwd,'/.tmp/',sep='')
logFile = file(paste(dataPath,'R.log',sep=''),open='wt')
sink(logFile,type='message')

source(paste(pwd,'server','scripts','strategy.r',sep='/'))

getCandles <- function(instrument=NA, granularity=NA, startDate = NA, count = NA, restore=F){
	inFile = paste(ifelse(restore,paste(dataPath,'candles/',sep=''),tmpPath), instrument, '-', granularity,sep='')
	
	if(!is.na(count) & !restore){
		inFile = paste(inFile,'-',count,sep='')
	}
	inFile = paste(inFile,ifelse(restore,'csv','json'),sep='.')
	print(paste('importing from',inFile,sep=' '))

	if(!restore){
		json = fromJSON(readChar(inFile,nchars=1e6))
		print('done importing json candles')

		ret = NULL
		for(c in 1:length(json$candles)){
			candle = as.data.frame(json$candles[c])
			rbind(ret, candle) -> ret
		}

		ret = ret[,-(grep('[a-z]+Ask|complete',names(ret)))]
		rownames(ret) = ret[,1]
		ret = ret[,-1]

		colnames(ret) = c('Open','High','Low','Close','Volume')
		ddates = as.POSIXct(strptime(rownames(ret), tz = "UTC", "%Y-%m-%dT%H:%M:%OSZ"))
		rownames(ret) = ddates
		ret = as.xts(ret)
	}else{
		ret = read.csv(inFile)
		rownames(ret)=as.POSIXct(ret$Time,origin="1970-01-01")
		ret = as.xts(ret)
	}

	return(ret)
}

getLiveCandles <- function(instrument, granularity, startDate = NA, count = 600, endDate=NA){
	urlPractice = paste('https://api-fxpractice.oanda.com/v1/candles?instrument=', instrument, '&granularity=', granularity, '&dailyAlignment=0&weeklyAlignment=Monday', '&candleFormat=bidask', sep = '')

	if(!is.na(startDate)){
		urlPractice = paste(urlPractice,'&start=', startDate,sep='')
	}else if(!is.na(count)){
		urlPractice = paste(urlPractice,'&count=', count,sep='')
	}
  
	if(!is.na(endDate)){
	  urlPractice = paste(urlPractice,'&end=', endDate,sep='')
	}

	print(paste('requesting ',urlPractice))

	json = fromJSON(getURL(url = urlPractice, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken))))

	ret = NULL
	for(c in 1:length(json$candles)){
		candle = as.data.frame(json$candles[c])
		rbind(ret, candle) -> ret
	}

	ret = ret[,-(grep('[a-z]+Ask|complete',names(ret)))]
	rownames(ret) = ret[,1]
	ret = ret[,-1]
	names(ret) = c('Open','High','Low','Close','Volume')
  ddates = as.POSIXct(strptime(rownames(ret), tz = "UTC", "%Y-%m-%dT%H:%M:%OSZ"))
	rownames(ret) = ddates
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

getPips <- function(p1, p2){
  p1=round(p1,4)
  p2=round(p2,4)
  pdif=formatC(round(p2-p1,4), format='f', digits=4)
  return(as.double(gsub('^\\d\\.(.*)$', '\\1', pdif)))
}

getVolatility <- function(crosses){
	ret = xts()
	for(cross in crosses){
		tmp = getCandles(cross,'H1',count = 168,restore=T)
		vol = volatility(tmp[,c("Open","High","Low","Close")], n=6,calc='garman.klass')
		names(vol) = c(cross)
		ret = cbind(vol,ret)
	}
	ret = na.omit(ret)
	return(last(ret))
}

getSlopeByPeriod <- function(curr, period){
	newCount = 0
	switch(period,M15={
		newCount = 96
	},H1={
		newCount = 168
	},H4={
		newCount = 180
	},D={
		newCount = 365
	})
	print(paste('getSlopeByPeriod',curr,period,newCount,sep='-'))
	tmp = getCandles(curr,period,count = newCount,restore=T)
	roc = na.omit(ROC(Cl(tmp),type='discrete'))
	#vroc = na.omit(ROC(tmp$Volume,type='discrete'))
	#lmm = lm(roc~vroc)
	lmm = lm(roc~seq_along(roc))
	f = as.numeric(fitted(lmm))

	return(last(atan(f)))
}

getCrossesStrengthPerPeriod <- function(crosses){
	periods = c('M15','H1','H4','D')
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

getSupportsAndResistances <- function(candles,threshold=7){
	prices = HLC(candles)
	dc = lag(DonchianChannel(Cl(prices),n=20),-2)
	dc$count = 1

	t = table(dc$high)
	t2 = table(dc$low)
	resistances = as.double(names(t[t>=threshold]))
	supports = as.double(names(t2[t2>=threshold]))
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

angle <- function(x,y){
  dot.prod <- x%*%y 
  norm.x <- norm(x,type="2")
  norm.y <- norm(y,type="2")
  theta <- acos(dot.prod / (norm.x * norm.y))
  as.numeric(theta)
}

graphRobustLines <- function(symbol=NA, graph=T, period=NA, candles=NA){
  p2 = NULL
  
  if(is.na(candles)){
    candles = get(symbol)
  }

  if(!is.na(candles)){
    if(is.na(period)){
      hlc = HLC(candles)
    }else{
      hlc = last(HLC(candles), period)
    }

    ddates = index(hlc)
    f1=line(log(as.numeric(FRAMA(hlc,n=60,FC=65,SC=162)$FRAMA)))
    f2=line(log(as.numeric(FRAMA(hlc,n=12,FC=13,SC=32)$FRAMA)))
    co=coef(f1)
    co2=coef(f2)
    fit1 = fitted(f1)
    fit2 = fitted(f2)
    
    #cc=rbind(co,co2)
    #intersection=c(-solve(cbind(cc[,2],-1)) %*% cc[,1])[2]
    intersection = mean(c(fitted(f1),fitted(f2)))
    
    rl = list(co1=co,co2=co2,intersection=intersection)
    
    lf = mean(c(last(fit1),last(fit2)))
    un = seq(from=rl$intersection,to=lf,length.out = max(length(fit1),length(fit2)))
    
    f3=line(un)
    co3=coef(f3)
    rl$co3 = co3
    
    rl$fit = fitted(f3)
    
    dd <- data.frame(x=1:length(rl$fit),rl$fit,rl$intersection)
    s1 <- coef(lm(rl.fit~x,dd))[2]
    s2=coef(lm(rl.intersection~x,dd))[2]
    ar=atan2(s1-s2,1)
    
    rl$angle = ar*180/pi
    
    if(graph){
      ff = as.numeric(FRAMA(hlc,n=12,FC=13,SC=32)$FRAMA)
      p2 <- ggplot()+
      geom_line(data=as.data.frame(log(ff)),aes(x=index(ff),y=log(ff)))+
      geom_abline(slope=co3[2],intercept = co3[1],color="orange")+
      geom_hline(yintercept = intersection,color="orange")
      
      return(p2)
    }
    
    return(rl)
  }
}

snapshot <- function(candles = NA, ptitle = NA){
  if(is.na(ptitle)){
    ptitle = deparse(substitute(candles))
  }
  
  par(mar=c(4,2.5,3.5,2.5),mfrow=c(2,2))
  #layout(matrix(c(1,1,2,3),2,2,byrow=T))
  
  mm=qfxMomentum(data = tail(candles,n=365),graph = F)
  ssrr=getSupportsAndResistances(tail(candles,n=365*1),threshold = 10)
  
  p1 = qfxSnake(data = candles, graph = T)
  p2 = graphRobustLines(symbol = ptitle,candles = tail(candles,n=365), graph = T)
  p3 = qfxSnake(data = tail(candles,n=365*1), graph = T)
  
  #for(r in ssrr$resistances){abline(h=r,col='blue')}
  #for(r in ssrr$supports){abline(h=r,col='red')}
  
  #axis(4,at=round(c(ssrr$resistances,ssrr$supports),3),cex.axis=0.8)
  
  p4 <- ggplot()+geom_line(data = mm, aes(x=index(mm),y=qm))
  
  multiplot(p1,p2,p3,p4,cols = 2)
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

drawTrend <- function(candles){
	x = as.numeric(Cl(candles))
	fit = lm(x~seq_along(x))
	co=coef(fit)
	abline(co[1],0,col='yellow',lwd=1) # pivot
	abline(co[1],co[2],col='yellow',lwd=1) # slope
}

graphBreakoutArea <- function(instrument='EUR_USD',granularity='D',candles=NA,save=T,showGraph=F,fillCongested=T,drawLines=F){
	if(is.na(candles)){
		switch(granularity,M15={
			newCount = 96
		},H1={
			newCount = 168
		},H4={
			newCount = 180
		},D={
			newCount = 365
		})
		candles = getCandles(instrument,granularity,count=newCount,restore=F)
	}
	prices = HLC(candles)
	ret = getSupportsAndResistances(candles)

	if(!is.null(ret$resistances)&!is.null(ret$supports)){
		if(showGraph){
			#dev.new()
			lineChart(Cl(candles),name=paste(instrument,granularity,sep=' - '))
		}
		if(save){
			iname = paste(dataPath,'breakout/', instrument, '-', granularity, '.jpg', sep = '')
			print(paste('saving image',iname))
			png(iname,width=maxWidth,height=maxHeight)
			lineChart(Cl(candles),name=paste(instrument,granularity,sep=' - '))
			print('done')
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

		drawTrend(candles)

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

getCOTData <- function(yearsAgo=0){
	week = format(Sys.time(),'%U');
	month = format(Sys.time(),'%m');
	year = as.integer(format(Sys.time(),'%Y'))-yearsAgo;

	url = 'http://www.cftc.gov/files/dea/history/deacot{{year}}.zip';
	urlFinal = gsub('\\{\\{year\\}\\}',year,url);
	reportName = 'annual.txt';
	tmp = paste(tmpPath,'cot',week,year,'.zip',sep='')#tempfile(tmpdir='/tmp');
	
	if(!file.exists(tmp)){
		download.file(urlFinal,tmp);
	}

	unzip(tmp,files=c(reportName));
	data = read.table(reportName, sep = ',', dec = '.', strip.white = TRUE, header=TRUE, encoding = 'UTF-8');
	data = subset(data,CFTC.Market.Code.in.Initials=='CME'|CFTC.Market.Code.in.Initials=='ICUS');
	data[,1] = gsub('(.*)\\s+\\-\\s+.*','\\1',data[,1],ignore.case=T,perl=T);

	unlink(reportName)

	return(data)
}

getCOTPosition <- function(currency,data=NA){
	currency = as.character(currency)
	data = data[order(as.Date(data$As.of.Date.in.Form.YYYY.MM.DD, format='%Y-%m-%d')),]
	curr = subset(data,Market.and.Exchange.Names==currency)
	cl = ROC(curr$Noncommercial.Positions.Long..All,type='continuous')
	cs = ROC(curr$Noncommercial.Positions.Short..All,type='continuous')
	ci = ROC(curr$Open.Interest..All,type='continuous')
	pos = matrix(c(cl,cs,ci),ncol=3,dimnames=list(NULL,c('long','short','interest')))
	ret = last(zoo(pos))
	index(ret) = c(currency)
	return(ret)
}

getCOTPositions <- function(currency,data=NA){
	data = data[order(as.Date(data$As.of.Date.in.Form.YYYY.MM.DD, format='%Y-%m-%d')),]
	curr = subset(data,Market.and.Exchange.Names==currency)
	curr$netdiff = curr$Noncommercial.Positions.Long..All.-curr$Noncommercial.Positions.Short..All.
	cn = curr$netdiff
	ci = curr$Open.Interest..All.
	pos = matrix(c(cn,ci),ncol=2,dimnames=list(NULL,c('netpos','interest')))
	ret = zoo(pos)
	ret$market = curr$Market.and.Exchange.Names
	index(ret) = as.Date(curr$As.of.Date.in.Form.YYYY.MM.DD)
	return(ret)
}

graphCOTPositioning <- function(currency1,currency2,cross,data=NA,cotData=NA,save=T,showGraph=F){
	print(paste('Graphics for COT',currency1,currency2,cross,sep=' '))

	if(is.na(data)){
		#data = getSymbols(cross,src='oanda',auto.assign=F)
		data = getCandles(instrument=cross,granularity="D",count=365)
	}
	
	if(is.na(cotData)){
		cotData = getCOTData(2) # should be 1, but until we get 2016 info is 2 years before now
		cotData = rbind(cotData,getCOTData(1)) # should be 0, but until we get 2016 info is last year
		cotData = cotData[order(as.Date(cotData$As.of.Date.in.Form.YYYY.MM.DD, format='%Y-%m-%d')),]
	}

	if(showGraph){
		dev.new()
	}

	mindate = min(as.Date(cotData$As.of.Date.in.Form.YYYY.MM.DD))
	maxdate = max(as.Date(cotData$As.of.Date.in.Form.YYYY.MM.DD))
	candles = data[as.Date(index(data)) >= mindate & as.Date(index(data)) <= maxdate,]
	index(candles) = as.Date(index(candles))
	candles = Cl(candles)

	pos1 = getCOTPositions(currency1,cotData)
	pos2 = getCOTPositions(currency2,cotData)
	pos1 = pos1[index(pos1) >= min(index(candles)) & index(pos1) <=  max(index(candles)),]
	pos2 = pos2[index(pos2) >= min(index(candles)) & index(pos2) <=  max(index(candles)),]
	tmp = na.locf(merge(pos1,pos2,candles))

	netpos1 = EMA(scale(as.double(tmp$netpos.pos1)),n=5)
	netpos1 = as.zoo(netpos1)
	index(netpos1) = index(candles)
	interest1 = EMA(scale(as.double(tmp$interest.pos1)),n=5)
	interest1 = as.zoo(interest1)
	index(interest1) = index(candles)

	netpos2 = EMA(scale(as.double(tmp$netpos.pos2)),n=5)
	netpos2 = as.zoo(netpos2)
	index(netpos2) = index(candles)
	interest2 = EMA(scale(as.double(tmp$interest.pos2)),n=5)
	interest2 = as.zoo(interest2)
	index(interest2) = index(candles)

	if(save){
		instrument = sub('/','_',cross)
		iname = paste(dataPath,'cot/', instrument, '.png', sep = '')
		png(iname,width=maxWidth,height=maxHeight)
	}

	par(bg='dimgray',mar=c(4,2.5,3.5,2.5),mfrow=c(3,1),ps = 12, cex = 1, cex.main = 1)
	plot(candles,type='l',ylab=NA,xlab=NA,cex.axis=1,col.lab='white',col.axis='white')
	title(main=cross, col.main='white',cex=10,col = 'white', font=4)

	plot(netpos1,type='l',col='yellow',ylab=NA,xlab=NA,cex.axis=1.5,col.lab='white',col.axis='white',lwd=2,ylim=c(min(c(as.double(netpos1),as.double(interest1)),na.rm=T),max(c(as.double(netpos1),as.double(interest1)),na.rm=T)))
	title(main=currency1, col.main='white',cex=10,col = 'white', font=4)
	abline(h=0,col='grey')
	lines(interest1,col='sienna1',lwd=2)

	plot(netpos2,type='l',col='yellow',ylab=NA,xlab=NA,cex.axis=1.5,col.lab='white',col.axis='white',lwd=2,ylim=c(min(c(as.double(netpos2),as.double(interest2)),na.rm=T),max(c(as.double(netpos2),as.double(interest2)),na.rm=T)))
	title(main=currency2, col.main='white',cex=10,col = 'white', font=4)
	abline(h=0,col='grey')
	lines(interest2,col='sienna1',lwd=2)

	par(xpd=T)
	legend('bottomright', c('net position','interest'),col=c('yellow','sienna1'),lty=c(1,1),text.col='white',cex=c(1.5),pt.cex=c(1.5),bty='n',pch=c(15),pt.lwd=0)

	# add copyright
	year = format(Sys.time(),'%Y')
	path = paste(dataPath,'../images/logo-s.png',sep='')
	logo = readPNG(path)
	addCopyright(paste('Powered by ',sep=''),logo,x = unit(0.5, 'npc'), y = unit(0.942, 'npc'),1,fontsize=10, col='white')

	if(save){
		dev.off()
	}
}

getCurrencyFundamentalStrength <- function(calendar = NA, w = 52, country1=NA, country2=NA){
	reDate = '([^\\s]+)(?:\\s+[^\\s]+){1,}'
	df = data.frame()
	for(i in 1:length(calendar)){
		cal = calendar[[i]]

		if(length(cal$Data)==0){
			next
		}
		rowData = sapply(cal$Data,unlist)
		actual = rowData['Actual',]
		actual = actual[actual!='' && !is.na(actual)]

		if(length(actual)==0){
			next
		}

		tmpDf = data.frame()
		actual = as.numeric(na.omit(actual))
		avg = mean(actual)
		tmpDf[1,'name'] = cal$Name
		tmpDf[1,'code'] = cal$EventCode
		tmpDf[1,'country'] = cal$Country
		tmpDf[1,'date'] = cal$Released
		tmpDf[1,'actual'] = avg
		df = rbind(tmpDf,df)
	}

	df$date = gsub(reDate,'\\1',df$date,perl=T)
	df$date = as.Date(df$date,format='%m/%d/%Y')
	df = df[order(df$date),]

	startWeek = as.Date(format(Sys.Date(),format='%Y-%m-%d')) - as.difftime(w,units='weeks')
	tmp = df[df$date>=startWeek,]

	if(!is.na(country1) && !is.na(country2)){
		tmp = tmp[grep(paste(country1,country2,sep='|'), tmp$country, ignore.case=TRUE),]
	}

	# invert value for unemployment
	inv = 'unempl|jobless'
	tmp[grep(inv,tmp$name, ignore.case=TRUE),'actual'] = -(tmp[grep(inv,tmp$name, ignore.case=TRUE),'actual'])
	
	tmp = aggregate(tmp$actual, by=list(code=tmp$code,country=tmp$country),FUN=diff)
	tmp[,'x'] = sapply(tmp[,'x'],simplify=T,FUN=function(n) round(sum(n),6))
	tmp$scale = round(scale(tmp[,'x'], scale = TRUE, center = TRUE), 6)
	tmp = tmp[!is.na(tmp$scale),]

	scaled = aggregate(tmp$scale, by=list(country=tmp$country),FUN=mean)
	names(scaled) <- c('country','strength')
	scaled = scaled[order(-scaled[,'strength']),]
	scaled$sd = sd(scaled$strength)
	scaled$strength = scale(scaled$strength+scaled$sd,center=T)
	return(scaled)
}

getMarketChange <- function(){
	dataset = read.csv(file = paste(dataPath,'multisetsInputs.csv',sep=''),sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")

	dates = dataset$Date
	rownames(dataset) = dates
	dataset = as.xts(dataset)
	dataset$Date = NULL

	dataset = apply(dataset,2,FUN=function(x){round(as.double(x),6)})
	rownames(dataset) = dates
	dataset = na.locf(as.xts(dataset))
	ret.daily = last(ROC(dataset,n=3))
	ret.weekly = last(ROC(dataset[endpoints(dataset,on="weeks",k=1),]))
	ret.monthly = last(ROC(dataset[endpoints(dataset,on="months",k=1),]))
	ret.annual = last(ROC(dataset[endpoints(dataset,on="years",k=1),]))

	return(list(daily=ret.daily,weekly=ret.weekly,monthly=ret.monthly,annual=ret.annual))
}

qfxMarketChange <- function(){
	print(paste('Running qfxMarketChange. Data path is',dataPath,sep=' '))
	outFile = paste(dataPath,'marketChange', '.csv', sep = '')

	chg = getMarketChange()
	periods = c('daily','weekly','monthly','annual')
	ret = data.frame(row.names=periods)
	cols = names(chg[[1]])
	data = matrix(unlist(chg),byrow=T,nrow=length(periods))
	rownames(data) = periods
	colnames(data) = cols
	data = cbind(data,periods)
	colnames(data)[which(colnames(data)=='periods')] = 'period'
	colnames(data) = toupper(gsub("\\.{3}[\\w]+|CURRFX\\.|\\.\\d+|\\.Price", "", colnames(data), perl = TRUE))

	print(paste('saving to',outFile))
	write.csv(data, quote = FALSE, row.names = FALSE, file = outFile, fileEncoding = 'UTF-8')
}

qfxAnalysis <- function(args){
	print(paste('Running qfxAnalysis. Data path is',dataPath,sep=' '))
	args = fromJSON(args)
	outFile = paste(dataPath,'candles/', args$instrument, '-', args$granularity, '.csv', sep = '')

	out = getCandles(args$instrument, args$granularity, args$startDate,count=args$count)
	out = OHLC(out)

	trend = TrendDetectionChannel(out, n = 20, DCSector = .25)
	trend$Time = 0
	trend$Time = index(out)
	out = cbind(out,trend)

	patterns = getCandlestickPatterns(out)
	out = cbind(out,patterns)

	#out = cbind(out, qfxMomentum(OHLC(out),emaPeriod=2))

	# Rserve ignores call to png. Move this to custom script
	#graphBreakoutArea(args$instrument,args$granularity,candles=OHLC(out))
	print(paste('saving to',outFile))
	write.csv(out, quote = FALSE, row.names = FALSE, file = outFile, fileEncoding = 'UTF-8')
}

qfxBatchAnalysis <- function(args){
	args = fromJSON(args)
	for(c in crosses){
		opts=toJSON(list(instrument=c,granularity=args$granularity,count=args$count,startDate=NULL))
		qfxAnalysis(opts)
		qfxBreakout(opts)
	}
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

qfxGraphCOTPositioning <- function(args){
	print(paste('Running qfxGraphCOTPositioning. Data path is',dataPath,sep=' '))
	args = fromJSON(args)
	graphCOTPositioning(args$currency1, args$currency2,args$instrument)
}

qfxBatchCOTPositioning <- function(args){
	print(paste('Running qfxCOTPositioning. Data path is',dataPath,sep=' '))
	args = fromJSON(args)
	graphCOTPositioning(args$currency1, args$currency2,args$instrument)
}

qfxEventsStrength <- function(args){
	args = fromJSON(args)

	if(is.null(args$country1)){
		args$country1 = NA
	}
	if(is.null(args$country2)){
		args$country2 = NA
	}

	reDate = '([^\\s]+)(?:\\s+[^\\s]+){1,}'
	calendar = fromJSON(file=paste(dataPath,'calendar.json',sep=''))
	
	datess=sapply(calendar$d,"[[","Released")
	datess=as.Date(datess,format="%m/%d/%Y")
	calendar = calendar$d[order(datess)]
	
	total = length(calendar)
	last = calendar[[total]]
	lastDate = gsub(reDate,'\\1',last$Released,perl=T)
	endDate = format(Sys.Date(),format='%m/%d/%Y')

	diffWeeks = as.integer(difftime(as.Date(endDate,format='%m/%d/%Y'),as.Date(lastDate,format='%m/%d/%Y'),units='weeks'))
	startWeek = as.Date(format(Sys.Date(),format='%Y-%m-%d')) - as.difftime(diffWeeks,units='weeks')
	startDate = format(startWeek,format='%m/%d/%Y')

	url = 'http://www.forex.com/uk/UIService.asmx/getEconomicCalendarForPeriod'
	params = toJSON(list(aStratDate=startDate,aEndDate=endDate))
	headers = list('Accept' = 'application/json', 'Content-Type' = 'application/json')
	ret = fromJSON(postForm(url, .opts=list(postfields=params, httpheader=headers)))

	calendar = append(calendar, ret$d)
	datess=sapply(calendar,"[[","Released")
	datess=as.Date(datess,format="%m/%d/%Y")
	calendar = calendar[order(datess)]

	strength = getCurrencyFundamentalStrength(calendar, as.integer(args$weeks), args$country1, args$country2)
	outFile = paste('calendar',as.integer(args$weeks),sep = '-')
	if(!is.na(args$country1) && !is.na(args$country2)){
		outFile = paste(outFile,args$country1,args$country2, sep = '-')
	}
	outFile = paste(outFile,'strength', sep = '-')
	write.csv(strength, quote = FALSE, row.names = FALSE, file =  paste(dataPath, paste(outFile,'.csv',sep=''),sep=''), fileEncoding = 'UTF-8')
}

qfxQmSignal <- function(args = NA, crosses = NA, granularity = NA, restoreCsv = NA){
	args = ifelse(!is.na(args),fromJSON(args),NA)
	hasCustomCrosses = !is.na(crosses)
	
	if(!is.na(args)){
  	granularity = args$granularity
  	restoreCsv = as.integer(args$csv)
  	crosses = args$crosses
	}
  	
	switch(granularity,M15={
		newCount = 96
	},H1={
		newCount = 168
	},H4={
		newCount = 180
	},D={
		newCount = 365
	})

	tmp = xts()
	for(cross in crosses){
	  if(hasCustomCrosses){
	    candles = OHLC(get(cross))
	  }else{
	    candles = getCandles(cross,granularity,count=newCount,restore=restoreCsv)
	  }

		if(restoreCsv==F){
			qm = qfxMomentum(OHLC(candles),emaPeriod=2)$qm
		}else{
			qm = candles$signal
		}

		names(qm) = cross
		tmp = cbind(tmp, last(qm,1))
	}

	tmp = t(tmp)
	tmp = data.frame(cross=rownames(tmp),qm=tmp[,],row.names=NULL)
	tmp = tmp[order(tmp$qm),]

	return(tmp)
}

qfxBatchSignals <- function(data = NA){
	periods = c('M15','H1','H4','D')

	tmp = NULL

	for(p in periods){
	  if(is.na(data)){
		  qm = qfxQmSignal(toJSON(c(granularity=p,csv=1)))
	  }else{
	    qm = qfxQmSignal(toJSON(c(granularity=p,csv=0,candles=data)))
	  }
		rownames(qm) = qm$cross
		qm[,p] = qm$qm
		qm[,'cross'] = NULL
		qm[,'qm'] = NULL
		if(is.null(tmp)){
			tmp = qm
		}else{
			tmp = cbind(tmp, qm)
		}
	}

	#tmp[tmp <= (-0.5)] = 1
	#tmp[tmp >= 1.25] = -1
	#tmp[tmp<1&tmp > -1] = 0
	tmp = tmp[rowSums(tmp==0)!=length(periods),]
	tmp$cross = rownames(tmp)

	write.csv(as.matrix(tmp), append = FALSE, quote = FALSE, row.names = FALSE, file = paste(dataPath,'signal.csv',sep=''), fileEncoding = 'UTF-8')

	return(tmp)
}

# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                     ncol = cols, nrow = ceiling(numPlots/cols))
  }
  
  if (numPlots==1) {
    print(plots[[1]])
    
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

drawPriceLine <- function(data = NA){
  return(ggplot()+geom_line(data = data,aes(x=index(data),y=Close))+theme(axis.line=element_blank(),
                                                                                         axis.text.x=element_blank(),
                                                                                         axis.text.y=element_blank(),
                                                                                         axis.ticks=element_blank(),
                                                                                         axis.title.x=element_blank(),
                                                                                         axis.title.y=element_blank(),
                                                                                         legend.position="none",
                                                                                         panel.background=element_blank(),
                                                                                         panel.border=element_blank(),
                                                                                         panel.grid.major=element_blank(),
                                                                                         panel.grid.minor=element_blank(),
                                                                                         plot.background=element_blank()))
}