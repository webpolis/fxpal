pwd = getwd()
source(paste(pwd,'server','scripts','header.r',sep='/'))

library(httr)

oanda.account.info.type = "practice"
oanda.account.info.strategy = "snake"
oanda.account.info.accountId = 4952957
oanda.account.info.period = "M15"

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
    openOrderId = NULL
    openOrderTime = NULL
    opSide = NULL
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
      openOrderTime = as.POSIXlt(gsub('T|\\.\\d{6}Z', ' ', openTrade$time))
      direction = ifelse(openSide=="buy",1,-1)
    }
    
    signalCut = 1
    
    switch(oanda.account.info.strategy, snake={
      signals = getQfxSnakeStrategySignals(symbol = symbol)
    }, momentum={
      signals = getQfxMomentumStrategySignals(symbol = symbol)
    })
    
    ret = tail(signals,signalCut)
    ret[ret==0] = NA
    lastSignalTime = as.POSIXlt(gsub('T|\\.\\d{6}Z', ' ', rownames(ret)[1]))
    
    if(nrow(ret)>0){
      if(!is.na(ret["longEntry"])){
        direction = 1
      }else if(!is.na(ret["shortEntry"])){
        direction = -1
      }
        
      if(!is.na(direction)){
        side = ifelse(direction>0,"long","short")
        literalSide = ifelse(direction>0,"buy","sell")
        opSide = ifelse(side=="long","short","long")
      }else{
        next
      }

      if(hasOpenTrade && (!is.na(ret[paste0(openSide,"Exit")]) || !is.na(ret[paste0(openOpSide,"Entry")]))){
        # close open trade        
        if(!is.null(openOrderId) && !is.null(openOrderTime)){
          print(paste("closing",symbol))
          oanda.close(orderId = openOrderId)
          hasOpenTrade = F
        }
      }
      
      if(!hasOpenTrade && !is.na(ret[paste0(side,"Entry")])){
        # open trade
        print(paste(symbol,side))
        oanda.open(type = "market",side = literalSide,cross = cross)
      } else{
        print(paste(cross,"no action taken"))
      }
    }else{
      print(paste(cross,"no action taken: no recent signals"))
    }
  }
}
