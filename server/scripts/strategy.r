Sys.setenv(TZ="UTC")

pwd = dirname(sys.frame(1)$ofile)

source(paste(pwd,"/candlesticks.r",sep=""))
library("quantmod")
library("PerformanceAnalytics")

TradingStrategy <- function(strategy, data,param1=NA,param2=NA,param3=NA){
  tradingreturns = NULL
  returns = CalculateReturns(Cl(data))
  runName = NULL
  signal = 0

  switch(strategy, CCI={
    cci <- CCI(HLC(data),n=param1)
    signal <- apply(cci,1,function (x) {if(is.na(x["cci"])){ return (0) } else { if(x["cci"]>100){return (1)} else if(x["cci"]<(-100)) {return (-1)}else{ return(0)}}})
  }, MACD={
    macd <- MACD(Cl(data),param1,param2,param3,maType=list(list(EMA),list(EMA),list(SMA)))
    signal <- apply(macd,1,function (x) { if(is.na(x["macd"]) | is.na(x["signal"])){ return (0) } else { if(x["macd"]>0 & x["signal"]>0){return (1)} else if(x["macd"]<0 & x["signal"]<0) {return (-1)}else{ return(0)}}})
  })

  runName <- paste(strategy,param1,param2,param3,sep=",")
  tradingreturns = signal * returns
  colnames(tradingreturns) <- runName
  print(paste("Running Strategy: ",runName))

  return (tradingreturns)
}

RunIterativeStrategy <- function(data, strategy = NA){
  #This function will run the TradingStrategy
  #It will iterate over a given set of input variables
  #In this case we try lots of different periods for the moving average
  firstRun <- TRUE
  results = NULL

  switch(strategy, CCI={
    for(paramA in 7:20) {
      runResult <- TradingStrategy(strategy, data,paramA)
      if(firstRun){
        firstRun <- FALSE
        results <- runResult
      } else {
        results <- cbind(results,runResult)
      }
    }
  }, MACD={
    for(paramA in 4:12) {
      for(paramB in 4:20) {
        for(paramC in 4:20) {
          runResult <- TradingStrategy(strategy, data,paramA,paramB,paramC)
          if(firstRun){
            firstRun <- FALSE
            results <- runResult
          } else {
            results <- cbind(results,runResult)
          }
        }
      }
    }
  })

  return(results)
}

CalculatePerformanceMetric <- function(returns,metric){
  #Get given some returns in columns
  #Apply the function metric to the data
  print (paste("Calculating Performance Metric:",metric))
  metricFunction <- match.fun(metric)
  if(length(grep("sharperatio",metric,ignore.case=T))>0){
    periods = 252

    if(length(grep("[a-z]\\d+",metric,ignore.case=T))>0){
      unit = gsub("([a-z])(\\d+)","\\1","H1",ignore.case=T)
      num = as.integer(gsub("([a-z])(\\d+)","\\1","H1",ignore.case=T))
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

FindOptimumStrategy <- function(trainingData, strategy = NA){
  #Optimise the strategy
  trainingReturns <- RunIterativeStrategy(trainingData, strategy)
  pTab <- PerformanceTable(trainingReturns)
  toptrainingReturns <- SelectTopNStrategies(trainingReturns,pTab,"SharpeRatio",5)

  dev.new()
  charts.PerformanceSummary(toptrainingReturns,main=paste(strategy,"- Training"),geometric=FALSE)
  return (pTab)
}
#1
trainStrategy <- function(instrument,granularity,strategy){
  data = getCandles(instrument,granularity,count=600)
  startDate = index(data[1,])
  ##endDate = index(data[ceiling(nrow(data)/2),])
  endDate = index(data[nrow(data),])
  trainingData <- window(data, start =startDate, end = endDate)
  pTab <- FindOptimumStrategy(trainingData,strategy) #pTab is the performance table of the various parameters tested
}
#2
testStrategy <- function(instrument,granularity,count,strategy,param1=NA,param2=NA,param3=NA){
  data = getCandles(instrument,granularity,count=count)
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

getSignals <- function(data=NA){
  # CCI+MACD
  tmp = cbind(data, CCI(HLC(data),n=7))
  tmp = cbind(tmp, MACD(Cl(tmp),4,5,5,maType=list(list(EMA),list(EMA),list(SMA))))
  buysell = as.xts(apply(tmp, 1, function(x){if(is.na(x["cci"])|is.na(x["macd"])|is.na(x["signal"])){x["buysell"]=0}else if(x["cci"]>100 & x["macd"]>0 & x["signal"]>0){x["buysell"]=1}else if(x["cci"]<(-100) & x["macd"]<0 & x["signal"]<0){x["buysell"]=-1}else{x["buysell"]=0}}))
  names(buysell) = c("CCI+MACD")

  ret = cbind(data,buysell)

  return(ret)
}