oanda.account <- function(accountId, accountType = c("trade", "practice")){
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

oanda.init <- function(accountId=2110611,accountType="practice"){
  oanda.portfolio<<-getQfxPortfolio()
  oanda.symbols<<-as.character(lapply(oanda.portfolio$cross,FUN=function(cross){cross = tolower(gsub("[^A-Za-z]+","",cross))}))
  rm(list=oanda.symbols)
  oanda.account.info.id <<- accountId
  oanda.account.info.type <<- accountType
  oanda.account.info <<- oanda.account(accountId, accountType)
}

oanda.tick <- function(){
  oanda.account.info <<- oanda.account(oanda.account.info.id, oanda.account.info.type)
  oanda.trades.open <<- oanda.trades()
  oanda.trades.open.crosses <<- as.character(lapply(oanda.trades.open,FUN=function(x){x$instrument}))
#   oanda.signals<<-batchMomentumStrategy(oanda.portfolio$cross,c("M15"))
#   oanda.signals.tmp <<- last(oanda.signals,8)
#   oanda.signals.tmp <<- oanda.signals.tmp[,colSums(oanda.signals.tmp^2)!=0]
#   oanda.signals.tmp[oanda.signals.tmp==0] <<- NA
#   oanda.signals.tmp <<- na.locf(oanda.signals.tmp)
#   oanda.signals <<- last(oanda.signals.tmp)
  
#   for(n in names(oanda.signals.tmp)){
#     symbol = tolower(gsub("[^A-Za-z]+|\\.\\w+\\d+","",n))
#     momentum = qfxMomentum(data = get(symbol), emaPeriod = 2)
#     if(momentum[,"angle"] > 0 && oanda.signals[,n] > 0){
#       print(paste(symbol,"buy"))
#     }else if(momentum[,"angle"] < 0 && oanda.signals[,n] < 0){
#       print(paste(symbol,"sell"))
#     }
#   }

  for(cross in oanda.portfolio$cross){
    hasOpenTrade = length(grep(cross,oanda.trades.open.crosses,value=T)) > 0
    ret = NULL
    symbol = tolower(gsub("[^A-Za-z]+|\\.\\w+\\d+","",cross))
    eval(parse(text=paste0(symbol,"<<-","getQfxCandles('",cross,"','M15')")))
    
    momentum = qfxMomentum(data = get(symbol), emaPeriod = 2, debug=F)
    if(momentum[,"angle"] > 0){
      ret = getQfxMomentumStrategySignals(symbol = symbol, long = T)
      ret = tail(ret,8)
      ret[ret==0] = NA
      ret = na.locf(ret)
      
      if(nrow(ret)>0){
        print(paste(symbol,"buy"))
      }
    }else if(momentum[,"angle"] < 0){
      ret = getQfxMomentumStrategySignals(symbol = symbol, long = F)
      ret = tail(ret,8)
      ret[ret==0] = NA
      ret = na.locf(ret)
      
      if(nrow(ret)>0){
        print(paste(symbol,"sell"))
      }
    }
  }
}