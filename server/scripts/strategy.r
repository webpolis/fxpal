tmpGranularity = NA

TradingStrategy <- function(strategy=NA, data=NA,param1=NA,param2=NA,param3=NA, retSignals=F,V1=NA,V2=NA,V3=NA){
  tradingreturns = NULL
  returns = Delt(Op(data),Cl(data))
  names(returns)<-c("return")
  runName = NULL
  signal = 0

  param1 = ifelse(is.na(V1),param1,V1)
  param2 = ifelse(is.na(V2),param2,V2)
  param3 = ifelse(is.na(V3),param3,V3)

  print(paste(strategy,param1,param2,param3,sep="-"))

  switch(strategy, , qfxMomentum={
    qm = qfxMomentum(OHLC(data),emaPeriod=param1)
    signal = apply(qm,1,function (x) {if(is.na(x["signal"])){ return (0) } else { if(x["signal"]>=1.1){return (-1)} else if(x["signal"]<=(-1.1)) {return (1)}else{ return(0)}}})
  }, ADXATR={
    adx = ADX(HLC(data),n=param1)
    atr = ATR(HLC(data),n=param2)
    tmp = cbind(adx,atr)
    signal = apply(tmp,1,function (x) {if(is.na(x["atr"])|is.na(x["DIp"])|is.na(x["DIn"])){ return (0) } else if(x["atr"]>0.0011&x["DIp"]>30&x["DIn"]<20){return (1)}else if(x["atr"]>0.0011&x["DIp"]<20&x["DIn"]>30){return (-1)}else if(x["atr"]<0.0006&x["DIp"]>30&x["DIn"]<20){return (1)}else if(x["atr"]<0.0006&x["DIp"]<20&x["DIn"]>30){return (-1)}else{return(0)}})
  }, CCI={
    cci = CCI(Op(data),n=param1)
    signal = apply(cci,1,function (x) {if(is.na(x["cci"])){ return (0) } else { if(x["cci"]>100){return (1)} else if(x["cci"]<(-100)) {return (-1)}else{ return(0)}}})
  }, MACD={
    macd = MACD(Op(data),nFast=param1,nSlow=param2,nSig=param3,maType=list(list(EMA),list(EMA),list(SMA)))
    signal = apply(macd,1,function (x) { if(is.na(x["macd"]) | is.na(x["signal"])){ return (0) } else { if(x["macd"]>x["signal"] & x["signal"]>0){return (1)} else if(x["macd"]<x["signal"] & x["signal"]<0) {return (-1)}else{ return(0)}}})
  }, EMA={
    ema1 = EMA(Op(data),n=param1)
    ema2 = EMA(Op(data),n=param2)
    ema3 = EMA(Op(data),n=param3)
    emas = cbind(ema1,ema2,ema3)
    names(emas) = c("ema1","ema2","ema3")
    signal = apply(emas,1,function (x) {if(is.na(x["ema1"])|is.na(x["ema2"])|is.na(x["ema3"])){ return (0) } else { if(x["ema1"]>x["ema2"]&x["ema2"]>x["ema3"]){return (1)} else if(x["ema1"]<x["ema2"]&x["ema2"]<x["ema3"]){return (-1)}else{return(0)}}})
  }, SMI={
    smi = SMI(Op(data),nFast=param1,nSlow=param2,nSig=param3,maType=list(list(SMA), list(EMA, wilder=TRUE), list(SMA)))
    signal = apply(smi,1,function (x) {if(is.na(x["SMI"])|is.na(x["signal"])){ return (0) } else { if(x["SMI"]>20&x["SMI"]<x["signal"]){return (-1)} else if(x["SMI"]<(-20)&x["SMI"]>x["signal"]){return (1)}else{return(0)}}})
  }, RSI={
    rsi = RSI(Op(data),n=param1)
    signal = apply(rsi,1,function (x) {if(is.na(x["EMA"])){ return (0) } else { if(x["EMA"]>60){return (-1)} else if(x["EMA"]<=30){return (1)}else{return(0)}}})
  }, STOCH={
    stch = stoch(Op(data),nFastK=param1,nFastD=param1,nSlowD=param1,maType=list(list(SMA), list(EMA, wilder=TRUE), list(SMA)))
    stch = stch*100
    stch = as.xts(apply(stch,1,mean))
    names(stch) = c("stoch")
    signal = apply(stch,1,function (x) {if(is.na(x["stoch"])){ return (0) } else { if(x["stoch"]>=70){return (-1)} else if(x["stoch"]<=30){return (1)}else{return(0)}}})
  }, ADX={
    adx = ADX(HLC(data),n=param1)
    signal = apply(adx,1,function (x) {if(is.na(x["ADX"])|is.na(x["DIn"])|is.na(x["DIp"])){ return(0) } else { if(x["ADX"]>13&x["DIp"]>x["DIn"]){return(1)} else if(x["ADX"]>13&x["DIp"]<x["DIn"]){return(-1)}else{return(0)}}})
  }, SAR={
    sar = SAR(HLC(data))
    names(sar) = c("sar")
    signal = apply(cbind(HLC(data),sar),1,function (x) {if(is.na(x["sar"])|is.na(x["High"])|is.na(x["Low"])){ return (0) } else { if(x["sar"]<x["High"]&x["sar"]<x["Low"]){return (1)} else if(x["sar"]>x["High"]&x["sar"]>x["Low"]) {return (-1)}else{ return(0)}}})
  })

  runName = paste(strategy,param1,param2,param3,sep=",")
  tradingreturns = signal * returns
  signal = as.xts(signal)
  colnames(tradingreturns) <- runName
  colnames(signal) <- runName
  print(paste("Running Strategy: ",runName))

  if(!retSignals){
    return (tradingreturns)
  }else{
    return (signal)
  }
}

RunIterativeStrategy <- function(data, strategy = NA, paramsRange = NA, paramsCount = 1){
  #This function will run the TradingStrategy
  #It will iterate over a given set of input variables
  results = NULL
  min = 3
  max = 20
  loop = NULL
  
  if(!is.na(paramsRange)){
    min = min(paramsRange)
    max = max(paramsRange)
  }

  if(min%%1!=0&max%%1!=0){
    loop = seq(from = min, to = max, by = 0.1)
  }else{
    loop = seq(from = min, to = max, by = 1)
  }
  
  tmp = matrix(combn(loop,paramsCount),ncol=paramsCount,byrow=T)
  f = function(...){
    return(TradingStrategy(strategy, data, ...))
  }

  ix = 1
  for(i in loop){
    r = tmp[ix,]
    cols = paste(strategy,paste(as.character(r), collapse=","),sep=",")
    ret = do.call(f,as.list(r));
    if(is.null(results)){
      results = ret
    }else{
      results = cbind(results,ret)
    }
    ix = ix+1
  }

  return(results)
}

CalculatePerformanceMetric <- function(returns,metric){
  #Get given some returns in columns
  #Apply the function metric to the data
  print (paste("Calculating Performance Metric:",metric))
  metricFunction <- match.fun(metric)
  if(length(grep("sharperatio",metric,ignore.case=T))>0){
    periods = 252

    if(length(grep("[a-z]\\d+",tmpGranularity,ignore.case=T))>0){
      unit = gsub("([a-z])(\\d+)","\\1",tmpGranularity,ignore.case=T)
      num = as.integer(gsub("([a-z])(\\d+)","\\2",tmpGranularity,ignore.case=T))
      switch(unit, H={
          periods=8760/num
      }, M={
          periods=525600/num
      })
      if(unit=="M" & (is.na(num)|is.null(num))){
        periods = 12
      }
    }
    metricData <- as.matrix(metricFunction(returns,scale=periods))
  }else{
    metricData <- as.matrix(metricFunction(returns))
  }
  #Some functions return the data the wrong way round
  #Hence cant label columns to need to check and transpose it
  if(nrow(metricData) == 1){
  metricData <- t(metricData)
  }
  colnames(metricData) <- metric
  return (metricData)
}

PerformanceTable <- function(returns){
  pMetric <- CalculatePerformanceMetric(returns,"colSums")
  pMetric <- cbind(pMetric,CalculatePerformanceMetric(returns,"SharpeRatio.annualized"))
  pMetric <- cbind(pMetric,CalculatePerformanceMetric(returns,"maxDrawdown"))
  colnames(pMetric) <- c("Profit","SharpeRatio","MaxDrawDown")
  print("Performance Table")
  print(pMetric)
  return (pMetric)
}

OrderPerformanceTable <- function(performanceTable,metric){
  return (performanceTable[order(performanceTable[,metric],decreasing=TRUE),])
}

SelectTopNStrategies <- function(returns,performanceTable,metric,n){
#Metric is the name of the function to apply to the column to select the Top N
#n is the number of strategies to select
  pTab <- OrderPerformanceTable(performanceTable,metric)
  if(n > ncol(returns)){
   n <- ncol(returns)
  }
  strategyNames <- rownames(pTab)[1:n]
  topNMetrics <- returns[,strategyNames]
  return (topNMetrics)
}

FindOptimumStrategy <- function(trainingData, strategy = NA, paramsRange=NA,paramsCount=1){
  #Optimise the strategy
  trainingReturns <- RunIterativeStrategy(trainingData, strategy, paramsRange,paramsCount)
  pTab <- PerformanceTable(trainingReturns)
  toptrainingReturns <- SelectTopNStrategies(trainingReturns,pTab,"SharpeRatio",5)

  dev.new()
  charts.PerformanceSummary(toptrainingReturns,main=paste(strategy,"- Training"),geometric=FALSE)
  return (pTab)
}
#1
trainStrategy <- function(data,strategy, paramsRange=NA,paramsCount=1){
  startDate = index(data[1,])
  ##endDate = index(data[ceiling(nrow(data)/2),])
  endDate = index(data[nrow(data),])
  trainingData <- window(data, start =startDate, end = endDate)
  pTab <- FindOptimumStrategy(trainingData,strategy,paramsRange,paramsCount) #pTab is the performance table of the various parameters tested
}
#2
testStrategy <- function(data, instrument,strategy,param1=NA,param2=NA,param3=NA){
  #sampleStartDate = index(data[ceiling(nrow(data)/2)+1,])
  sampleStartDate = index(data[1,])
  testData <- window(data, start = sampleStartDate)
  indexReturns <- Delt(Cl(window(data, start = sampleStartDate)))
  colnames(indexReturns) <- paste(instrument, "Buy&Hold",sep=" ")
  dataOfSampleReturns <- TradingStrategy(strategy,testData,param1=param1,param2=param2,param3=param3)
  finalReturns <- cbind(dataOfSampleReturns,indexReturns)

  dev.new()
  charts.PerformanceSummary(finalReturns,main=paste(strategy,"- data of Sample"),geometric=FALSE)
}

qfxMomentum <- function(data,emaPeriod=19){
  stats = getSignals(data)
  stats$signal = round(DEMA(scale(stats$avg),emaPeriod,wilder=T),5)
  return(stats$signal)
}

getSignals <- function(data){
  # CCI+MACD
  ccimacd = cbind(TradingStrategy("CCI",data,18, retSignals=T),TradingStrategy("MACD",data,7,9,4, retSignals=T))
  names(ccimacd) = c("A.CCI","A.MACD")
  # RSI+SMI
  rsimsi = cbind(TradingStrategy("SMI",data,10,7,16, retSignals=T),TradingStrategy("RSI",data,14, retSignals=T))
  names(rsimsi) = c("B.SMI","B.RSI")
  # RSI+STOCH
  stochrsi = cbind(TradingStrategy("RSI",data,14, retSignals=T),TradingStrategy("STOCH",data,3,3,3, retSignals=T))
  names(stochrsi) = c("C.RSI","C.STOCH")
  # ADX+SAR
  adxsar = cbind(TradingStrategy("ADX",data,3, retSignals=T),TradingStrategy("SAR",data, retSignals=T))
  names(adxsar) = c("D.ADX","D.SAR")
  # EMA+STOCH
  stochema = cbind(TradingStrategy("EMA",data,6,11,5, retSignals=T),TradingStrategy("STOCH",data,3,3,3, retSignals=T))
  names(stochema) = c("E.EMA","E.STOCH")
  # ADX+ATR
  adxatr = TradingStrategy("ADXATR",data,3,7, retSignals=T)
  names(adxatr) = c("F.ADX.ATR")

  stats = cbind(ccimacd,rsimsi,stochrsi,adxsar,stochema,adxatr)
  stats$avg = rowMeans(stats[,1:ncol(stats)])
  stats$signal = DEMA(scale(stats$avg),5,wilder=T)

  return(stats)
}