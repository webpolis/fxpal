pwd = getwd()
source(paste(pwd,'server','scripts','header.r',sep='/'))

library(httr)

oanda.account <- function(accountId=2110611, accountType = "practice"){
  library("httr")
  
  # Check arguments
  accountType = match.arg(accountType)
  stopifnot(is.character(oandaToken))
  
  # Create URL
  url <- ifelse(accountType == "practice", "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", accountId)
  
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

oanda.prices <- function(instruments=NA, accountType="practice", fun = NA){
  json = NULL
  stopifnot(is.character(oandaToken), is.character(instruments)) #, class(since) == "Date" | is.null(since)
  base_url <- ifelse(accountType == "practice", "https://api-fxpractice.oanda.com/v1/prices?", "https://api-fxtrade.oanda.com/v1/prices?")
  url <- paste0(base_url, "instruments=", paste(instruments, collapse = "%2C"))
  getURL(url = url, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken)), write = function(ret){
    json = fromJSON(ret)
    fun(json)
  })
}

oanda.trades <- function(accountId=2110611,accountType="practice"){
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == "practice", "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", accountId, "/trades")
  json = fromJSON(getURL(url = url, httpheader = c('Accept' = 'application/json', Authorization = paste('Bearer ', oandaToken))))
  return(json$trades)
}

oanda.init <- function(accountId=2110611,accountType="practice",period="M15"){
  oanda.portfolio<<-getQfxPortfolio()
  oanda.symbols<<-as.character(lapply(oanda.portfolio$cross,FUN=function(cross){cross = tolower(gsub("[^A-Za-z]+","",cross))}))
  rm(list=oanda.symbols)
  oanda.account.info.id <<- accountId
  oanda.account.info.type <<- accountType
  oanda.account.info <<- oanda.account(accountId, accountType)
  oanda.account.info.period <<- period
  
  doDelay = 60*10
  
  switch(oanda.account.info.period, M15={
    doDelay = 60*(60*15)/100
  }, H1={
    doDelay = 60*(60*60)/100
  }, H4={
    doDelay = 60*(60*60*4)/100
  })
  
  while(TRUE){
    oanda.tick()
    Sys.sleep(doDelay)
  }
}

oanda.hasEnoughMoney <- function(){
  equity = oanda.account.info$marginUsed+oanda.account.info$marginAvail
  return(equity>(oanda.account.info$balance*50/100))
}

oanda.open <- function(accountId=2110611,accountType="practice",type="market",side=NA,cross=NA, units=2000){
  if(is.na(side) || is.na(cross)){
    return(NULL)
  }
  
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == "practice", "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", accountId, "/orders")
  POST(url, accept_json(), add_headers('Authorization' = paste('Bearer ', oandaToken), "Content-Type"="application/x-www-form-urlencoded"),
       body = list(instrument=cross, side = side, units = units, type=type),encode="form")
}

oanda.close <- function(accountId=2110611,accountType="practice",orderId=NA){
  if(is.na(orderId)){
    return(NULL)
  }
  
  stopifnot(is.character(oandaToken))
  url <- ifelse(accountType == "practice", "https://api-fxpractice.oanda.com/v1/accounts", "https://api-fxtrade.oanda.com/v1/accounts")
  url <- paste0(url, "/", accountId, "/trades/",orderId)
  DELETE(url, add_headers('Authorization' = paste('Bearer ', oandaToken)))
}

oanda.tick <- function(){
  oanda.account.info <<- oanda.account(oanda.account.info.id, oanda.account.info.type)
  oanda.trades.open <<- oanda.trades()
  oanda.trades.open.crosses <<- as.character(lapply(oanda.trades.open,FUN=function(x){x$instrument}))
  
  for(cross in oanda.portfolio$cross){
    openOrderId = NULL
    hasOpenTrade = length(grep(cross,oanda.trades.open.crosses,value=T)) > 0
    
    if(!hasOpenTrade && !oanda.hasEnoughMoney()){
      next
    }
    
    ret = NULL
    symbol = tolower(gsub("[^A-Za-z]+|\\.\\w+\\d+","",cross))
    eval(parse(text=paste0(symbol,"<<-","getQfxCandles('",cross,"','",oanda.account.info.period,"')")))
    
    momentum = qfxMomentum(data = get(symbol), emaPeriod = 2, debug=F)
    
    if(momentum[,"angle"]>0){
      direction = 1
    }else if(momentum[,"angle"]<0){
      direction = -1
    }else{
      next
    }
    
    if(hasOpenTrade){
      openTrade = Filter(function(x){x$instrument==cross},oanda.trades.open)[[1]]
      openSide = openTrade$side
      openOrderId = openTrade$id
      direction = ifelse(openSide=="buy",1,-1)
    }
    
    ret = getQfxMomentumStrategySignals(symbol = symbol, long = (ifelse(direction>0,T,F)))
    ret = tail(ret,8)
    ret[ret==0] = NA
    ret = tail(na.locf(ret),1)
    
    side = ifelse(direction>0,"long","short")
    literalSide = ifelse(direction>0,"buy","sell")
    
    if(nrow(ret)>0){
      if(!hasOpenTrade){
        # open trade
        print(paste(symbol,side))
        oanda.open(type = "market",side = literalSide,cross = cross)
      }else if(!is.na(ret[paste0(side,"Exit")])){
        # close open trade
        print(paste("closing",symbol))
        if(!is.null(openOrderId)){
          oanda.close(orderId = openOrderId)
        }
      }
    }
  }
}