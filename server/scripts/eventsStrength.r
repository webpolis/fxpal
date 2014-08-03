setwd("app/data/")

Sys.setenv(TZ="UTC")

opts = commandArgs(trailingOnly = TRUE)
weeks = ifelse((exists("opts") && !is.na(opts[1])), opts[1], 10)
cross1 = ifelse((exists("opts") && !is.na(opts[1])), opts[1], NA)
cross2 = ifelse((exists("opts") && !is.na(opts[1])), opts[1], NA)

getCurrenciesStrength <- function(w = 52, crossA=NA, crossB=NA){
	startWeek = as.Date(format(Sys.Date(),format="%Y-%m-%d")) - as.difftime(w,units="weeks")

	data = read.csv("calendar.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
	data = na.omit(data)
	data[,1] = as.Date(data[,1])
	data = data[data$date>=startWeek,]

	if(!is.na(crossA) && !is.na(crossB)){
		data = data[grep(paste(crossA,crossB,sep="|"), data$currency, ignore.case=TRUE),]
	}

	allValues = grep('actual|previous',names(data))

	# invert value for unemployment
	data[grep('continu_claim|jobless_claim|unempl',data$event, ignore.case=TRUE),allValues] = transform(data[grep('continu_claim|jobless_claim|unempl',data$event, ignore.case=TRUE),allValues],actual=-actual,previous=-previous)

	data = aggregate(data$actual, by=list(currency=data$currency,event=data$event),FUN=diff)
	data[,3] = sapply(data[,3],simplify=T,FUN=function(x) round(sum(x),6))
	names(data) = c("currency","event","value")
	data$scale = round(scale(data[,3], scale = TRUE, center = TRUE), 6)

	scaled = aggregate(data$value, by=list(currency=data$currency),FUN=mean)
	scaled = scaled[order(-scaled[,2]),]
	scaled[,2] = round(scale(scaled[,2], scale = TRUE, center = FALSE), 6)
	names(scaled) <- c("currency","strength")
	return(scaled)
}

