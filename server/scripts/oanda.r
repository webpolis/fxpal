pwd = getwd()
source(paste(pwd,'server','scripts','header.r',sep='/'))

library(httr)

oanda.account.info.type = "practice"
oanda.account.info.strategy = "snake"
oanda.account.info.accountId = 4952957
oanda.account.info.period = "M30"

oanda.account <- function(accountType = oanda.account.info.type){
  library("httr")
  
  # Check arguments
  accountType = match.arg(accountType)
  stopifnot(is.character(oandaToken))
  
  # Create URL
  url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", oanda.account.info.accountId)
  
  # Send Request
  get_request <- GET(url, add_headers(Authorization = paste0("Bearer ", oandaToken)))
  if(get_request$status_code != 200)
    stop(paste0("Request failed with code ", get_request$status_code," and error message:\n", content(get_request)$message))
  
  # Create dataframe
  results <- unlist(content(get_request))
  results_df <- data.frame(matrix(results, ncol = length(results), byrow = TRUE), 
                           stringsAsFactors = FALSE)
  colnames(results_df) <- names(results)
  
  # Format df
  for(i in c(3:10))
    results_df[,i] = as.numeric(results_df[,i])
  
  return(results_df)
}

oanda.prices <- function(instruments=NA, accountType=oanda.account.info.type){
  json = NULL
  stopifnot(is.character(oandaToken), is.character(instruments)) #, class(since) == "Date" | is.null(since)
  base_url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/prices?", "https://api-fxtrade.oanda.com/v1/prices?")
  url <- paste0(base_url, "instruments=", paste(instruments, collapse = "%2C"))
  ret = getURL(url = url, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken)))
  
  return(fromJSON(ret))
}

oanda.instruments <- function(instruments=NA, accountType=oanda.account.info.type, fun = NA){
  json = NULL
  stopifnot(is.character(oandaToken), is.character(instruments)) #, class(since) == "Date" | is.null(since)
  base_url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/instruments?", "https://api-fxtrade.oanda.com/v1/instruments?")
  url <- paste0(base_url, "instruments=", paste(instruments, collapse = "%2C"),"&fields=instrument%2Cpip%2Cprecision&accountId=",oanda.account.info.accountId)
  ret = getURL(url = url, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken)))
  
  return(fromJSON(ret))
}

oanda.history <- function(accountType=oanda.account.info.type,instrument=NA){
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", oanda.account.info.accountId, "/transactions")
  
  if(!is.na(instrument)){
    url <- paste0(url, "?instrument=",instrument)
  }

  json = fromJSON(getURL(url = url, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken))))
  return(json$transactions)
}

oanda.trades <- function(accountType=oanda.account.info.type){
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", oanda.account.info.accountId, "/trades")
  json = fromJSON(getURL(url = url, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken))))
  json$trades = lapply(json$trades, FUN = function(x){ x$time=as.POSIXct(strptime(x$time, tz = "UTC", "%Y-%m-%dT%H:%M:%OSZ")); x; })
  return(json$trades)
}

oanda.init <- function(accountType=oanda.account.info.type){
  oanda.portfolio<<-getQfxPortfolio()
  oanda.symbols<<-as.character(lapply(oanda.portfolio$cross,FUN=function(cross){cross = tolower(gsub("[^A-Za-z]+","",cross))}))
  rm(list=oanda.symbols)
  
  oanda.account.info.type <<- accountType
  oanda.account.info <<- oanda.account(accountType)
  oanda.account.info.instruments <<- oanda.instruments(oanda.portfolio$cross)
  
  doDelay = 60*10
  
  switch(oanda.account.info.period, M15={
    doDelay = 25*(60*15)/100
  }, M30={
    doDelay = 25*(60*30)/100
  },H1={
    doDelay = 25*(60*60)/100
  }, H4={
    doDelay = 25*(60*60*4)/100
  })
  
  while(TRUE){
    oanda.tick()

    Sys.sleep(doDelay)
    #Sys.sleep(30)
  }
}

oanda.hasEnoughMoney <- function(){
  equity = oanda.account.info$marginUsed+oanda.account.info$marginAvail
  return(equity>(oanda.account.info$balance*50/100))
}

oanda.open <- function(accountType=oanda.account.info.type,type="market",side=NA,cross=NA, units=2000){
  if(is.na(side) || is.na(cross)){
    return(NULL)
  }
  
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", oanda.account.info.accountId, "/orders")
  ret = POST(url, accept_json(), add_headers('Authorization' = paste('Bearer ', oandaToken), "Content-Type"="application/x-www-form-urlencoded"),
       body = list(instrument=cross, side = side, units = units, type=type),encode="form")
  print(ret)
}

oanda.close <- function(accountType=oanda.account.info.type,orderId=NA){
  if(is.na(orderId)){
    return(NULL)
  }
  
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == oanda.account.info.type, "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", oanda.account.info.accountId, "/trades/",orderId)
  DELETE(url, add_headers('Authorization' = paste('Bearer ', oandaToken)))
}

oanda.tick <- function(){
  oanda.account.info <<- oanda.account(oanda.account.info.type)
  oanda.trades.open <<- oanda.trades()
  oanda.trades.open.crosses <<- as.character(lapply(oanda.trades.open,FUN=function(x){x$instrument}))
  
  newCount = 0
  switch(oanda.account.info.period,M15={
    newCount = 96*2
  },M30={
    newCount = 240
  },H1={
    newCount = 168
  },H4={
    newCount = 180
  },D={
    newCount = 365
  })
  
  for(cross in oanda.portfolio$cross){
    openTrade = openSide = openOrderId = openOrderTime = openOpSide = openOrderDirection = NULL
    opSide = side = NULL
    direction = NA
    hasOpenTrade = length(grep(cross,oanda.trades.open.crosses,value=T)) > 0
    
    if(!hasOpenTrade && !oanda.hasEnoughMoney()){
      print("not enough free money")
      next
    }
    
    ret = NULL
    symbol = tolower(gsub("[^A-Za-z]+|\\.\\w+\\d+","",cross))
    eval(parse(text=paste0(symbol,"<<-","getLiveCandles('",cross,"','",oanda.account.info.period,"', count = ",newCount,")")))
    
    Sys.sleep(5)
    
    if(hasOpenTrade){
      openTrade = Filter(function(x){x$instrument==cross},oanda.trades.open)[[1]]
      openSide = ifelse(openTrade$side=="buy","long","short")
      openOpSide = ifelse(openSide=="long","short","long")
      openOrderId = openTrade$id
      openOrderTime = openTrade$time
      openOrderDirection = ifelse(openSide=="long",1,-1)
    }

    switch(oanda.account.info.strategy, snake={
      signals = getQfxSnakeStrategySignals(symbol = symbol)
    }, momentum={
      signals = getQfxMomentumStrategySignals(symbol = symbol)
    })
    
    signals = na.omit(signals)
    confirmedSignals = subset(signals,(shortEntry!=0|shortExit!=0|longEntry!=0|longExit!=0))
    ret = tail(confirmedSignals,1)

    if(nrow(ret)==0 || sum(is.na(ret))>0){
      print(paste(cross,"no action taken: no recent signals"))
      next
    }
    
    # on MT4, it's UTC-4
    lastSignalTime = ifelse(sum(is.na(ret))!=0,NA,rownames(ret)[1])
    
    if(ret["longEntry"]==1){
      direction = 1
    }else if(ret["shortEntry"]==1){
      direction = -1
    }

    if(!is.na(direction)){
      side = ifelse(direction==1,"long","short")
      literalSide = ifelse(direction==1,"buy","sell")
      opSide = ifelse(side=="long","short","long")
      literalOpSide = ifelse(opSide=="long","buy","sell")
    }

    # close existing trade for current iterated cross
    if(hasOpenTrade && lastSignalTime > openOrderTime 
       && (ret[paste0(openSide,"Exit")]!=0 || ret[paste0(openOpSide,"Entry")]!=0)){
      # close open trade        
      if(!is.null(openOrderId)){
        print(paste("closing",symbol))
        oanda.close(orderId = openOrderId)
      }
    }
    
    isNewSignal = rownames(ret)==rownames(tail(signals,1))
    if(isNewSignal){
      if(!is.null(openOpSide) && ret[paste0(openOpSide,"Entry")]!=0){
        side = openOpSide
      }
 
      # open trade
      print(paste(symbol,side))
      oanda.open(type = "market",side = literalSide,cross = cross)
    } else{
      print(paste(cross,"no action taken"))
    }
  }
}
