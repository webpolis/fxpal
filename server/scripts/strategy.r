Sys.setenv(TZ="UTC")

library("RCurl")
library("rjson")
library("candlesticks")
library("quantmod")
library("PerformanceAnalytics")

instrument = "EUR_USD"
granularity = "D"
oandaCurrencies = read.table("oandaCurrencies.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
isReverted = nrow(oandaCurrencies[oandaCurrencies$instrument == instrument,]) <= 0
instrument = ifelse(isReverted,sub("([a-z]{3})_([a-z]{3})", "\\2_\\1",instrument,ignore.case=TRUE),instrument)

getCandles <- function(instrument, granularity, startDate = NA, count = NA){
  oandaToken = 'ce6b72e81af59be0bbc90152cad8d731-03d41860ed7849e3c4555670858df786'
  urlPractice = paste("https://api-fxpractice.oanda.com/v1/candles?instrument=", instrument, "&granularity=", granularity, "&weeklyAlignment=Monday", "&candleFormat=bidask", sep = "")
  if(!is.na(startDate)){
    urlPractice = paste(urlPractice,"&start=", startDate,sep="")
  }
  if(!is.na(count)){
    urlPractice = paste(urlPractice,"&count=", count,sep="")
  }

  print(paste("requesting ",urlPractice))

  json = fromJSON(getURL(url = urlPractice, httpheader = c(Authorization = paste("Bearer ", oandaToken))))

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

TradingStrategy <- function(strategy, mktdata,param1,param2,param3){
  tradingreturns = NULL

  switch(strategy, CCI={
    runName <- paste(strategy,"(",param1,")",sep="")
    print(paste("Running Strategy: ",runName))
    #Calculate the Open Close return
    returns <- (Cl(mktdata)/Op(mktdata))-1
    #Calculate the moving averages
    cci <- CCI(HLC(mktdata),n=param1)
    #If mavga > mavgb go long
    signal <- apply(cci,1,function (x) { if(is.na(x)){ return (0) } else { if(x>100){return (1)} else if(x<-100) {return (-1)}else{ return(0)}}})
    tradingreturns <- signal * returns
    colnames(tradingreturns) <- runName
  }, MACD={
    runName <- paste(strategy,param1,param2,param3,sep=",")
    print(paste("Running Strategy: ",runName))
    #Calculate the Open Close return
    returns <- (Cl(mktdata)/Op(mktdata))-1
    #Calculate the moving averages
    macd <- MACD(Cl(mktdata),param1,param2,param3,maType=list(list(EMA),list(EMA),list(SMA)))
    #If mavga > mavgb go long
    signal <- apply(macd,1,function (x) { if(is.na(x["macd"]) | is.na(x["signal"])){ return (0) } else { if(x["macd"]>0 & x["signal"]>0){return (1)} else if(x["macd"]<0 & x["signal"]<0) {return (-1)}else{ return(0)}}})
    tradingreturns <- signal * returns
    colnames(tradingreturns) <- runName
  })

  return (tradingreturns)
}

RunIterativeStrategy <- function(mktdata, strategy = NA){
  #This function will run the TradingStrategy
  #It will iterate over a given set of input variables
  #In this case we try lots of different periods for the moving average
  firstRun <- TRUE
  results = NULL

  switch(strategy, CCI={
    for(paramA in 7:20) {
      runResult <- TradingStrategy(strategy, mktdata,paramA)
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
          runResult <- TradingStrategy(strategy, mktdata,paramA,paramB,paramC)
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
  metricData <- as.matrix(metricFunction(returns))
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
  charts.PerformanceSummary(toptrainingReturns,main=paste(nameOfStrategy,"- Training"),geometric=FALSE)
  return (pTab)
}

out = getCandles(instrument,granularity,count=600)
startDate = index(out[1,])
endDate = index(out[ceiling(nrow(out)/2),])
sampleStartDate = index(out[ceiling(nrow(out)/2)+1,])
nameOfStrategy <- "Strategy tester"
#Specify dates for downloading data, training models and running simulation
trainingData <- window(out, start =startDate, end = endDate)
testData <- window(out, start = sampleStartDate)
indexReturns <- Delt(Cl(window(out, start = sampleStartDate)))
colnames(indexReturns) <- paste(instrument, "Buy&Hold",sep=" ")

pTab <- FindOptimumStrategy(trainingData,"CCI") #pTab is the performance table of the various parameters tested
#Test out of sample
dev.new()
#Manually specify the parameter that we want to trade here, just because a strategy is at the top of
#pTab it might not be good (maybe due to overfit)
outOfSampleReturns <- TradingStrategy("CCI",testData,param1=30)
finalReturns <- cbind(outOfSampleReturns,indexReturns)
charts.PerformanceSummary(finalReturns,main=paste(nameOfStrategy,"- Out of Sample"),geometric=FALSE)