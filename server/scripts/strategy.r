library(iterators)
library(foreach)
library(doParallel)
library(FinancialInstrument)
library(CVMatcher)

registerDoParallel()

tmpGranularity = NA

getQfxCandles <- function(instrument=NA,granularity=NA){
  path = paste(instrument, granularity, sep="-")
  candles=read.csv(paste("http://qfx.club/data/candles/",path,".csv",sep=""))
  rownames(candles) = as.POSIXct(candles$Time,origin="1970-01-01")
  candles = candles[,c("Open","High","Low","Close")]
  candles=as.xts(candles)
  return(candles)
}

getQfxPortfolio <- function(){
  portfolio=read.csv(paste("http://qfx.club/data/","portfolio",".csv",sep=""))
  portfolio=portfolio[portfolio$percentage>0.2|portfolio$percentage<(-0.2),]
  portfolio$cross = gsub("(\\w{3})(\\w{3})","\\1_\\2",portfolio$cross)
  return(portfolio)
}

sigQmThreshold = function(label, data=mktdata, relationship=c("gt","lt","eq","gte","lte"),op=FALSE,cross=FALSE,cols=c("qmsd.qm","qm.qm")){
  relationship=relationship[1]
  ret_sig=NULL
  qmsd = ifelse(op,-(data[,cols[1]]),data[,cols[1]])
  qmsd = mean(qmsd)
  
  switch(relationship,
         '>' =,
         'gt' = {ret_sig = data[,cols[2]] > qmsd},
         '<' =,
         'lt' = {ret_sig = data[,cols[2]] < qmsd},
         'eq'     = {ret_sig = data[,cols[2]] == qmsd},
         'gte' =,
         'gteq'=,
         'ge'     = {ret_sig = data[,cols[2]] >= qmsd},
         'lte' =,
         'lteq'=,
         'le'     = {ret_sig = data[,cols[2]] <= qmsd}
  )
  if(isTRUE(cross)) ret_sig <- diff(ret_sig)==1
  if(!missing(label))
    colnames(ret_sig)<-label
  return(ret_sig)
}

snakeStrategyTest = function(symbol=NA, candles = NA, graph=T,long=F,returnOnly=F,both=F,opt=F){
  currency("USD")
  short = !long
  if(both){
    long = T
    short = T
  }
  
  if(is.na(candles)){
    candles = get(symbol)
  }
  
  stock(symbol,currency="USD",multiplier = 1)
  strategy.st = portfolio.st = account.st = "qfxSnakeStrategy"
  initEq = 20000
  tradeSize = initEq*.05
  rm.strat(strategy.st)
  to=as.character(Sys.Date())
  
  initDate=first(index(candles))
  initPortf(portfolio.st, symbols=symbol, initDate=initDate, currency='USD')
  initAcct(account.st, portfolios=portfolio.st, initDate=initDate, currency='USD',initEq=initEq)
  initOrders(portfolio.st, initDate=initDate)
  strategy(strategy.st, store=TRUE)
  
  add.indicator(strategy.st,name="qfxSnake",arguments = list(data=OHLC(candles),triggerN=9,triggerFC=14,triggerSC=24),label="snake")
  
  # sell
  if(short){
    print("short trading...")
    add.signal(strategy.st,name="sigThreshold",arguments = list(relationship="eq", column="snake.snake", threshold=-1),label="filterSnakeShort")
    add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("trigger.snake", "mean.snake"),relationship="lt"),label="filterFramaShort")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterSnakeShort","filterFramaShort"),cross=T),label="shortEntry")
    
    add.signal(strategy.st,name="sigThreshold",arguments = list(relationship="eq", column="snake.snake", threshold=1),label="filterSnakeExitShort")
    add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("trigger.snake","mean.snake"),relationship="gt"),label="filterFramaExitShort")
    #add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("Close", "trigger.snake"),relationship="gt"),label="filterFramaExitShort")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterSnakeExitShort","filterFramaExitShort"),cross=T),label="shortExit")
    
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="shortEntry", sigval=TRUE, ordertype="market", 
                            orderside="short", replace=FALSE, prefer="Open", 
                            osFUN=osMaxDollar, tradeSize=-(tradeSize), maxSize=-(tradeSize)), 
             type="enter", path.dep=TRUE)
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="shortExit", sigval=TRUE, orderqty="all", 
                            ordertype="market", orderside="short", replace=FALSE, 
                            prefer="Open"), 
             type="exit", path.dep=TRUE)
  }
  
  # buy
  if(long){
    print("long trading...")
    add.signal(strategy.st,name="sigThreshold",arguments = list(relationship="eq", column="snake.snake", threshold=1),label="filterSnakeLong")
    add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("trigger.snake", "mean.snake"),relationship="gt"),label="filterFramaLong")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterSnakeLong","filterFramaLong"),cross=T),label="longEntry")
    
    add.signal(strategy.st,name="sigThreshold",arguments = list(relationship="eq", column="snake.snake", threshold=-1),label="filterSnakeExitLong")
    add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("trigger.snake","mean.snake"),relationship="lt"),label="filterFramaExitLong")
    #add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("Close", "trigger.snake"),relationship="lt"),label="filterFramaExitLong")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterSnakeExitLong","filterFramaExitLong"),cross=T),label="longExit")
    
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="longEntry", sigval=TRUE, ordertype="market", 
                            orderside="long", replace=FALSE, prefer="Open", 
                            osFUN=osMaxDollar, tradeSize=tradeSize, maxSize=tradeSize), 
             type="enter", path.dep=TRUE)
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="longExit", sigval=TRUE, orderqty="all", 
                            ordertype="market", orderside="long", replace=FALSE, 
                            prefer="Open"), 
             type="exit", path.dep=TRUE)
  }
  
  strat = list(strategy=strategy.st, portfolios=portfolio.st)
  
  if(returnOnly){
    return(strat)
  }
  
  if(!opt){
    applyStrategy(strategy=strat$strategy,portfolios=strat$portfolios)
    updatePortf(strat$portfolios)
    updateAcct(strat$portfolios)
    updateEndEq(strat$strategy)
  }
  
  if(opt){
    vN=(8:13)
    vFC=(10:20)
    vSC=(20:30)
    add.distribution(strategy.st, paramset.label = "qfxSnake", component.type = "indicator", component.label = "snake", 
                     variable = list(triggerN=vN), label="snakeOptN")
    add.distribution(strategy.st, paramset.label = "qfxSnake", component.type = "indicator", component.label = "snake", 
                     variable = list(triggerFC=vFC), label="snakeOptFC")
    add.distribution(strategy.st, paramset.label = "qfxSnake", component.type = "indicator", component.label = "snake", 
                     variable = list(triggerSC=vSC), label="snakeOptSC")
    ret = apply.paramset(strategy.st, paramset.label = "qfxSnake", portfolio.st = portfolio.st, account.st=account.st, nsamples=0)
    
    optimized=as.data.frame(ret$tradeStats)
    optimized=head(optimized[order(optimized$Net.Trading.PL, optimized$Ann.Sharpe, optimized$Profit.Factor, decreasing = T),])
  }else{
    optimized = NA
    chart.Posn(strat$portfolios)
  }  

  return(list(optimized=optimized, strat=strat))
}

momentumStrategyTest = function(symbol=NA, graph=T,long=F,returnOnly=F, both=F,opt=F){
  currency("USD")
  short = !long
  
  if(both){
    short = T
    long = T
  }
  
  candles = get(symbol)
  stock(symbol,currency="USD",multiplier = 1)
  strategy.st = portfolio.st = account.st = "qfxMomentumStrategy"
  initEq = 20000
  tradeSize = initEq*.05
  rm.strat(strategy.st)
  to=as.character(Sys.Date())
  initDate=first(index(candles))
  initPortf(portfolio.st, symbols=symbol, initDate=initDate, currency='USD')
  initAcct(account.st, portfolios=portfolio.st, initDate=initDate, currency='USD',initEq=initEq)
  initOrders(portfolio.st, initDate=initDate)
  strategy(strategy.st, store=TRUE)
  
  add.indicator(strategy.st,name="qfxMomentum",arguments = list(data=OHLC(candles),emaPeriod=11,debug=F),label="qm")
  add.indicator(strategy.st,name="FRAMA",arguments = list(HLC=OHLC(candles),n=12,FC=13,SC=32),label="frama.fast")
  add.indicator(strategy.st,name="FRAMA",arguments = list(HLC=OHLC(candles),n=60,FC=65,SC=162),label="frama.slow")
  
  # sell
  if(short){
    print("short trading...")
    add.signal(strategy.st,name="sigQmThreshold",arguments = list(relationship="gt"),label="filterQmShort")
    add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("FRAMA.frama.fast","FRAMA.frama.slow"),relationship="lte"),label="filterFramaShort")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterQmShort","filterFramaShort"),cross=T),label="shortEntry")
    
    add.signal(strategy.st,name="sigQmThreshold",arguments = list(relationship="lte", op=T),label="filterQmShortExit")
    add.signal(strategy.st, name="sigComparison",
               arguments = list(columns=c("FRAMA.frama.fast","FRAMA.frama.slow"),relationship="gt"),label="filterFramaShortExit")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterQmShortExit","filterFramaShortExit"),cross=T),label="shortExit")
  
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="shortEntry", sigval=TRUE, ordertype="market", 
                            orderside="short", replace=FALSE, prefer="Open", 
                            osFUN=osMaxDollar, tradeSize=-(tradeSize), maxSize=-(tradeSize)), 
             type="enter", path.dep=TRUE)
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="shortExit", sigval=TRUE, orderqty="all", 
                            ordertype="market", orderside="short", replace=FALSE, 
                            prefer="Open"), 
             type="exit", path.dep=TRUE)
  }
  
  # buy
  if(long){
    print("long trading...")
    add.signal(strategy.st,name="sigQmThreshold",arguments = list(relationship="lt",op=T),label="filterQmLong")
    add.signal(strategy.st,name="sigComparison",arguments = list(columns=c("FRAMA.frama.fast","FRAMA.frama.slow"),relationship="gte"),label="filterFramaLong")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterQmLong","filterFramaLong"),cross=T),label="longEntry")
    
    add.signal(strategy.st,name="sigQmThreshold",arguments = list(relationship="gte"),label="filterQmLongExit")
    add.signal(strategy.st, name="sigComparison",
               arguments = list(columns=c("FRAMA.frama.fast","FRAMA.frama.slow"),relationship="lt"),label="filterFramaLongExit")
    add.signal(strategy.st,name="sigAND",arguments = list(columns=c("filterQmLongExit","filterFramaLongExit"),cross=T),label="longExit")
    
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="longEntry", sigval=TRUE, ordertype="market", 
                            orderside="long", replace=FALSE, prefer="Open", 
                            osFUN=osMaxDollar, tradeSize=tradeSize, maxSize=tradeSize), 
             type="enter", path.dep=TRUE)
    add.rule(strategy.st, name="ruleSignal", 
             arguments=list(sigcol="longExit", sigval=TRUE, orderqty="all", 
                            ordertype="market", orderside="long", replace=FALSE, 
                            prefer="Open"), 
             type="exit", path.dep=TRUE)
  }
  
  strat = list(strategy=strategy.st, portfolios=portfolio.st)
  
  if(returnOnly){
    return(strat)
  }
  
  if(!opt){
    applyStrategy(strategy=strat$strategy,portfolios=strat$portfolios)
    updatePortf(strat$portfolios)
    updateAcct(strat$portfolios)
    updateEndEq(strat$strategy)
  }
  
  if(opt){
#     qmPeriod = 4:24
#     add.distribution(strategy.st, paramset.label = "qfxMomentum", component.type = "indicator", component.label = "qm", 
#                      variable = list(emaPeriod=qmPeriod), label="qmOptEmaPeriod")
#     ret = apply.paramset(strategy.st, paramset.label = "qfxMomentum", portfolio.st = portfolio.st, account.st=account.st, nsamples=0)
    vN=(8:14)
    vFC=(12:24)
    vSC=(16:34)
    
    add.distribution(strategy.st, paramset.label = "FRAMA", component.type = "indicator", component.label = "frama.fast", 
                     variable = list(n=vN), label="framaFastOptN")
    add.distribution(strategy.st, paramset.label = "FRAMA", component.type = "indicator", component.label = "frama.fast", 
                     variable = list(FC=vFC), label="framaFastOptFC")
    add.distribution(strategy.st, paramset.label = "FRAMA", component.type = "indicator", component.label = "frama.fast", 
                     variable = list(SC=vSC), label="framaFastOptSC")
    ret = apply.paramset(strategy.st, paramset.label = "FRAMA", portfolio.st = portfolio.st, account.st=account.st, nsamples=0)
    
    optimized=as.data.frame(ret$tradeStats)
    optimized=head(optimized[order(optimized$Net.Trading.PL, optimized$Ann.Sharpe, optimized$Profit.Factor, decreasing = T),])
  }else{
    optimized = NA
    chart.Posn(strat$portfolios)
  }  
  
  return(list(optimized=optimized, strat=strat))
}

getQfxMomentumStrategySignals <- function(symbol=NA,long=F,both=T){
  if(exists(symbol)){
    data = OHLC(get(symbol))
  }else{
    data = NULL
  }

  strat=momentumStrategyTest(symbol=symbol,long = (ifelse(both,F,long)), both=both,returnOnly = T)
  tt=applyStrategy(strategy=strat$strategy,portfolios=strat$portfolios,debug=T, mktdata = data)
  dd=data.frame(tt$qfxMomentumStrategy[[symbol]]$rules)
  dd=dd[,grep("pathdep\\.(?:long|short)(?:Exit|Entry)",names(dd))]
  names(dd) = gsub("pathdep\\.","",names(dd))
  return(dd)
}

getQfxSnakeStrategySignals <- function(symbol=NA,long=F,both=T){
  if(exists(symbol)){
    data = OHLC(get(symbol))
  }else{
    data = NULL
  }
  
  strat=snakeStrategyTest(symbol=symbol,long = (ifelse(both,F,long)), both=both, returnOnly = T)
  tt=applyStrategy(strategy=strat$strategy,portfolios=strat$portfolios,debug=T, mktdata = data)
  dd=data.frame(tt$qfxSnakeStrategy[[symbol]]$rules)
  dd=dd[,grep("pathdep\\.(?:long|short)(?:Exit|Entry)",names(dd))]
  names(dd) = gsub("pathdep\\.","",names(dd))
  return(dd)
}

batchMomentumStrategy <- function(crosses=NA,periods=NA){
  results= NULL
  for(cross in crosses){
    for(period in periods){
      symbol = tolower(gsub("[^A-Za-z]+","",cross))
      candles = getQfxCandles(instrument = cross, granularity = period)
      
      if(!exists(symbol)){
        eval(parse(text=paste(symbol, "candles",sep="<<-")))
      }else{
        eval(parse(text=paste(symbol,"<<-","rbind(candles,",symbol,")",sep="")))
      }
      
      eval(parse(text=paste(symbol,"<<-",symbol,"[!duplicated(index(",symbol,")),]",sep="")))
      
      ret = TradingStrategy(strategy = "qfxMomentum",data = get(symbol),param1 = 2,param2 = 3,param3 = 4,param4 = 40,param5=40,retSignals = T)
      names(ret) = c(paste(cross,period,sep="-"))
      if(is.null(results)){
        results = ret
      }else{
        results = cbind(results,ret)
      }
    }
  }
  
  return(results)
}

batchMomentum <- function(crosses=NA,periods=NA){
  results= NULL
  for(cross in crosses){
    for(period in periods){
      symbol = tolower(gsub("[^A-Za-z]+","",cross))
      candles = getQfxCandles(instrument = cross, granularity = period)
      
      if(!exists(symbol)){
        eval(parse(text=paste(symbol, "candles",sep="<<-")))
      }else{
        eval(parse(text=paste(symbol,"<<-","rbind(candles,",symbol,")",sep="")))
      }
      
      eval(parse(text=paste(symbol,"<<-",symbol,"[!duplicated(index(",symbol,")),]",sep="")))

      ret = qfxMomentum(data = get(symbol),emaPeriod = 11)
      names(ret) = c(paste(cross,period,"qm",sep="-"),paste(cross,period,"qmsd",sep="-"),paste(cross,period,"angle",sep="-"))
      if(is.null(results)){
        results = ret
      }else{
        results = cbind(results,ret)
      }
    }
  }
  
  return(results)
}

TradingStrategy <- function(strategy=NA, data=NA,param1=NA,param2=NA,param3=NA,param4=NA, param5=NA,retSignals=F,V1=NA,V2=NA,V3=NA, debug=T){
  tradingreturns = NULL
  returns = Delt(Op(data),Cl(data))
  names(returns)<-c("return")
  runName = NULL
  signal = 0
  
  param1 = ifelse(is.na(V1),param1,V1)
  param2 = ifelse(is.na(V2),param2,V2)
  param3 = ifelse(is.na(V3),param3,V3)
  
  switch(strategy, qfxSnake={
    ema1 = FRAMA(HLC(data),n=param1,FC=param2,SC = param1*2.5)$FRAMA
    snake = qfxSnake(data = data)
    frama = cbind(ema1$FRAMA, snake$snake, Cl(data))
    names(frama) = c("frama", "snake", "close")
    
    signal = apply(frama,1,function (x) {
      if(is.na(x["frama"]) || is.na(x["snake"]) || is.na(x["close"])){
        return (0)
      } else {
        if(x["close"] > x["frama"] && x["snake"] == 1){
          return (1)
        } else if(x["close"] < x["frama"] && x["snake"] == -1) {
          return (-1)
        }else{
          return(0)
        }
      }
    })
  }, FRAMA={
    frama1 = FRAMA(HLC(data),n=param1,FC=param2,SC = param3)$FRAMA
    frama2 = FRAMA(HLC(data),n=param1*2,FC=param2*2,SC = param3*2)$FRAMA
    frama1 = cbind(Cl(data), frama1, frama2)
    names(frama1) = c("close", "frama1", "frama2")
    
    signal = apply(frama1,1,function (x) {
      if(is.na(x["frama1"]) || is.na(x["frama2"])){
        return (0)
      } else {
        if(x["frama1"] > x["frama2"]){
          return (1)
        } else if(x["frama1"] < x["frama2"]) {
          return (-1)
        }else{
          return(0)
        }
      }
    })
  }, qfxMomentum={
    qm = qfxMomentum(OHLC(data),emaPeriod=param1)
    ema1 = FRAMA(HLC(data),n=param2,FC=param3,SC = param3*2.5)$FRAMA
    #ema2 = FRAMA(HLC(data),n=param4,FC=param4,SC = param5)$FRAMA
    ema2 = FRAMA(HLC(data),n=param2*5,FC=param3*5,SC = param3*5*2.5)$FRAMA
    qfxmomentum = cbind(qm,ema1,ema2)

    names(qfxmomentum) = c("qm","qmsd","angle","ema1","ema2")

    signal = apply(qfxmomentum,1,function (x) {
      if(is.na(x["qm"]) || is.na(x["qmsd"])){
        return (0)
      } else if(!is.na(x["ema1"]) && !is.na(x["ema2"])){
        if(x["qm"] < -(x["qmsd"]) && x["ema1"] >= x["ema2"]){
          return (1)
        } else if(x["qm"] > (x["qmsd"]) && x["ema1"] <= x["ema2"]) {
          return (-1)
        }else{
          return(0)
        }
      }else{
        return(0)
      }
    })
  }, ADXATR={
    adx = ADX(HLC(data),n=param1)
    atr = ATR(HLC(data),n=param2)
    tmp = cbind(adx,atr)
    signal = apply(tmp,1,function (x) {if(is.na(x["atr"])|is.na(x["DIp"])|is.na(x["DIn"])){ return (0) } else if(x["atr"]>0.0011&x["DIp"]>30&x["DIn"]<20){return (1)}else if(x["atr"]>0.0011&x["DIp"]<20&x["DIn"]>30){return (-1)}else if(x["atr"]<0.0006&x["DIp"]>30&x["DIn"]<20){return (1)}else if(x["atr"]<0.0006&x["DIp"]<20&x["DIn"]>30){return (-1)}else{return(0)}})
  }, CCI={
    cci = CCI(HLC(data),n=param1)
    signal = apply(cci,1,function (x) {if(is.na(x["cci"])){ return (0) } else { if(x["cci"]>100){return (1)} else if(x["cci"]<(-100)) {return (-1)}else{ return(0)}}})
  }, MACD={
    macd = MACD(Cl(data),nFast=param1,nSlow=param2,nSig=param3,maType=list(list(EMA),list(EMA),list(SMA)))
    signal = apply(macd,1,function (x) { if(is.na(x["macd"]) | is.na(x["signal"])){ return (0) } else { if(x["macd"]>x["signal"] & x["signal"]>0){return (1)} else if(x["macd"]<x["signal"] & x["signal"]<0) {return (-1)}else{ return(0)}}})
  }, EMA={
    ema1 = EMA(Op(data),n=param1)
    ema2 = EMA(Op(data),n=param2)
    ema3 = EMA(Op(data),n=param3)
    emas = cbind(ema1,ema2,ema3)
    names(emas) = c("ema1","ema2","ema3")
    signal = apply(emas,1,function (x) {if(is.na(x["ema1"])|is.na(x["ema2"])|is.na(x["ema3"])){ return (0) } else { if(x["ema1"]>x["ema2"]&x["ema2"]>x["ema3"]){return (1)} else if(x["ema1"]<x["ema2"]&x["ema2"]<x["ema3"]){return (-1)}else{return(0)}}})
  }, SMI={
    smi = SMI(HLC(data),nFast=param1,nSlow=param2,nSig=param3,maType=list(list(SMA), list(EMA, wilder=TRUE), list(SMA)))
    signal = apply(smi,1,function (x) {if(is.na(x["SMI"])|is.na(x["signal"])){ return (0) } else { if(x["SMI"]>20&x["SMI"]<x["signal"]){return (-1)} else if(x["SMI"]<(-20)&x["SMI"]>x["signal"]){return (1)}else{return(0)}}})
  }, RSI={
    rsi = RSI(Cl(data),n=param1)
    signal = apply(rsi,1,function (x) {if(is.na(x["EMA"])){ return (0) } else { if(x["EMA"]>60){return (-1)} else if(x["EMA"]<=30){return (1)}else{return(0)}}})
  }, STOCH={
    stch = stoch(HLC(data),nFastK=param1,nFastD=param2,nSlowD=param3,maType=list(list(SMA), list(EMA, wilder=TRUE), list(SMA)))
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
  
  runName = paste(strategy,param1,param2,param3,param4,param5,sep=",")
  tradingreturns = signal * returns
  signal = as.xts(signal)
  colnames(tradingreturns) <- runName
  colnames(signal) <- runName
  
  if(debug){
    print(paste("Running Strategy: ",runName))
  }
  
  if(!retSignals){
    return (tradingreturns)
  }else{
    return (signal)
  }
}

RunIterativeStrategy <- function(data = NA, strategy = NA, paramsRange = NA, paramsCount = 1, crosses = NA, periods = NA){
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
    return(TradingStrategy(strategy, ...))
  }

  if(!is.na(data)){
    for(i in 1:nrow(tmp)){
      r = tmp[i,]
      cols = paste(strategy,paste(as.character(r), collapse=","),sep=",")
      params = as.list(r)
      params$data = data
      ret = do.call(f,params);
      if(is.null(results)){
        results = ret
      }else{
        results = cbind(results,ret)
      }
    }
  }else if(!is.na(crosses) & !is.na(periods)){
    for(cross in crosses){
      for(period in periods){
        ix = 1
        candles = getQfxCandles(instrument = cross, granularity = period)
        for(i in loop){
          r = tmp[ix,]
          cols = paste(strategy,paste(as.character(r), collapse=","),sep=",")
          params = as.list(r)
          params$data = candles
          ret = do.call(f,params);
          if(is.null(results)){
            results = ret
          }else{
            results = cbind(results,ret)
          }
          ix = ix+1
        }
      }
    }
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

FindOptimumStrategy <- function(trainingData=NA, strategy = NA, paramsRange=NA,paramsCount=1, crosses = NA, periods = NA){
  #Optimise the strategy
  trainingReturns <- RunIterativeStrategy(trainingData, strategy, paramsRange,paramsCount, crosses=crosses,periods=periods)
  pTab <- PerformanceTable(trainingReturns)
  toptrainingReturns <- SelectTopNStrategies(trainingReturns,pTab,"SharpeRatio",5)
  
  dev.new()
  charts.PerformanceSummary(toptrainingReturns,main=paste(strategy,"- Training"),geometric=FALSE)
  return (pTab)
}
#1
trainStrategy <- function(data=NA,strategy, paramsRange=NA,paramsCount=1,crosses=NA,periods=NA){
  if(!is.na(data)){
    startDate = index(data[1,])
    ##endDate = index(data[ceiling(nrow(data)/2),])
    endDate = index(data[nrow(data),])
    trainingData <- window(data, start =startDate, end = endDate)
  }else{
    trainingData = NA
  }
  pTab <- FindOptimumStrategy(trainingData,strategy,paramsRange,paramsCount,crosses=crosses,periods=periods) #pTab is the performance table of the various parameters tested
}
#2
testStrategy <- function(data, instrument,strategy,param1=NA,param2=NA,param3=NA,param4=NA,param5=NA){
  #sampleStartDate = index(data[ceiling(nrow(data)/2)+1,])
  sampleStartDate = index(data[1,])
  testData <- window(data, start = sampleStartDate)
  indexReturns <- Delt(Cl(window(data, start = sampleStartDate)))
  colnames(indexReturns) <- paste(instrument, "Buy&Hold",sep=" ")
  outOfSampleReturns <- TradingStrategy(strategy,testData,param1=param1,param2=param2,param3=param3,param4=param4,param5=param5)
  finalReturns <- cbind(outOfSampleReturns,indexReturns)
  
  dev.new()
  charts.PerformanceSummary(finalReturns,main=paste(strategy,"- out of Sample"),geometric=FALSE)
}

qfxMomentum <- function(data,emaPeriod=11, debug=T, graph = F, symbol = ""){
  stats = getSignals(data,debug)
  stats$qm = round(DEMA(scale(stats$avg),emaPeriod,wilder=T),5)
  qmsd = sd(na.omit(stats$qm))
  stats$qmsd = qmsd + ((.01*3)*qmsd)
  stats = stats[,c("qm","qmsd")]
  rl = graphRobustLines(candles = data,graph = graph, symbol = symbol)
  stats$angle = rl$angle
  return(stats)
}

qfxSnake <- function(data = NA, triggerN = 9, triggerFC = 14, triggerSC = 24, graph = F, save = F, name=NA){
  p1 = NULL
  fr9=FRAMA(HLC(data),n = 12,FC=13,SC=32)
  fr45=FRAMA(HLC(data),n = 60,FC=65,SC=162)
  fr13=FRAMA(HLC(data),n = triggerN,FC=triggerFC,SC=triggerSC)
  ff=cbind(fr9$FRAMA,fr45$FRAMA)
  ff$mean=rowMeans(ff)
  ret = ifelse(ff$FRAMA>ff$FRAMA.1,1,-1)
  names(ret) = c("snake")
  ret$mean = ff$mean
  ret$trigger = fr13$FRAMA
  
  if(save && !is.na(name)){
    jpeg(filename = paste0(name,".png"),width=maxWidth,height=maxHeight)
  }
  
  if(graph){
    data = OHLC(data)
    names(data) <- c("Open", "High", "Low", "Close")
    p1 <- ggplot()+
    geom_point(data=ret,aes(x=index(ret),y=mean,color="mean"),color=ifelse(ret$snake==1,"green","red"))+
    geom_line(data=ret,aes(x=index(ret),y=trigger,color="trigger"),color="blue")+
    geom_line(data=data,aes(x=index(ret),y=Close,color="close"), color="black")
  }
  
  if(save){
    dev.off()
  }
  
  if(!graph){
    return(ret)  
  }
  
  return(p1)
}

getSignals <- function(data,debug){
  # CCI+MACD
  ccimacd = cbind(TradingStrategy("CCI",data,18, retSignals=T, debug=debug),TradingStrategy("MACD",data,7,9,4, retSignals=T, debug=debug))
  names(ccimacd) = c("A.CCI","A.MACD")
  # RSI+SMI
  rsimsi = cbind(TradingStrategy("SMI",data,10,7,16, retSignals=T, debug=debug),TradingStrategy("RSI",data,14, retSignals=T, debug=debug))
  names(rsimsi) = c("B.SMI","B.RSI")
  # RSI+STOCH
  stochrsi = cbind(TradingStrategy("RSI",data,14, retSignals=T, debug=debug),TradingStrategy("STOCH",data,2,3,8, retSignals=T, debug=debug))
  names(stochrsi) = c("C.RSI","C.STOCH")
  # ADX+SAR
  adxsar = cbind(TradingStrategy("ADX",data,3, retSignals=T, debug=debug),TradingStrategy("SAR",data, retSignals=T, debug=debug))
  names(adxsar) = c("D.ADX","D.SAR")
  # EMA+STOCH
  stochema = cbind(TradingStrategy("EMA",data,6,11,5, retSignals=T, debug=debug),TradingStrategy("STOCH",data,2,3,8, retSignals=T, debug=debug))
  names(stochema) = c("E.EMA","E.STOCH")
  # ADX+ATR
  adxatr = TradingStrategy("ADXATR",data,3,7, retSignals=T, debug=debug)
  names(adxatr) = c("F.ADX.ATR")
  
  stats = cbind(ccimacd,rsimsi,stochrsi,adxsar,stochema,adxatr)
  stats$avg = rowMeans(stats[,1:ncol(stats)])
  
  return(stats)
}

cvMatcherMultiPeriod <- function(tpl, sample, min, max){
  tplName = deparse(substitute(tpl))
  sampleName = deparse(substitute(sample))  
    
  cc = c("period", "shapeMatch", "distRotAngle", "distPcaAngle", "pcaAngleSample", 
         "pcaAngleTpl", "rangeStart", "rangeEnd")
  out=data.frame(matrix(ncol=length(cc),nrow = 0))
  colnames(out) <- cc
  
  names(tpl) <- gsub("[A-Za-z]+\\.","",names(tpl))
  names(sample) <- gsub("[A-Za-z]+\\.","",names(sample))
  
  for(p in min:max) {
    out2=CVMatcher::process(OHLC(tpl),OHLC(sample),p);

    if(length(out2)>0)
      out=merge(out, out2, all = T)
  }
  
  out=out[with(out, order(distPcaAngle, shapeMatch, distRotAngle)),]
  out$tpl = tplName
  out$sample = sampleName
  
  return(out)
}